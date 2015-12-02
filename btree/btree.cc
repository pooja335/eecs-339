#include <assert.h>
#include "btree.h"

KeyValuePair::KeyValuePair()
{}


KeyValuePair::KeyValuePair(const KEY_T &k, const VALUE_T &v) : 
key(k), value(v)
{}


KeyValuePair::KeyValuePair(const KeyValuePair &rhs) :
key(rhs.key), value(rhs.value)
{}


KeyValuePair::~KeyValuePair()
{}


KeyValuePair & KeyValuePair::operator=(const KeyValuePair &rhs)
{
      return *( new (this) KeyValuePair(rhs));
}




BTreeIndex::BTreeIndex(SIZE_T keysize, 
 SIZE_T valuesize,
 BufferCache *cache,
 bool unique) 
{
      superblock.info.keysize=keysize;
      superblock.info.valuesize=valuesize;
      buffercache=cache;
  // note: ignoring unique now
}

BTreeIndex::BTreeIndex()
{
  // shouldn't have to do anything
}
//
// Note, will not attach!
//
BTreeIndex::BTreeIndex(const BTreeIndex &rhs)
{
      buffercache=rhs.buffercache;
      superblock_index=rhs.superblock_index;
      superblock=rhs.superblock;
}

BTreeIndex::~BTreeIndex()
{
  // shouldn't have to do anything
}

BTreeIndex & BTreeIndex::operator=(const BTreeIndex &rhs)
{
      return *(new(this)BTreeIndex(rhs));
}



//node (de)allocation
ERROR_T BTreeIndex::AllocateNode(SIZE_T &n)
{
      n=superblock.info.freelist;

      if (n==0) { 
            return ERROR_NOSPACE;
    }

    BTreeNode node;

    node.Unserialize(buffercache,n);

    assert(node.info.nodetype==BTREE_UNALLOCATED_BLOCK);

    superblock.info.freelist=node.info.freelist;

    superblock.Serialize(buffercache,superblock_index);

    buffercache->NotifyAllocateBlock(n);

    return ERROR_NOERROR;
}

ERROR_T BTreeIndex::DeallocateNode(const SIZE_T &n)
{
      BTreeNode node;

      node.Unserialize(buffercache,n);

      assert(node.info.nodetype!=BTREE_UNALLOCATED_BLOCK);

      node.info.nodetype=BTREE_UNALLOCATED_BLOCK;

      node.info.freelist=superblock.info.freelist;

      node.Serialize(buffercache,n);

      superblock.info.freelist=n;

      superblock.Serialize(buffercache,superblock_index);

      buffercache->NotifyDeallocateBlock(n);

      return ERROR_NOERROR;

}



//attach/detach
ERROR_T BTreeIndex::Attach(const SIZE_T initblock, const bool create)
{
      ERROR_T rc;

      superblock_index=initblock;
      assert(superblock_index==0);

      if (create) {
    // build a super block, root node, and a free space list
    //
    // Superblock at superblock_index
    // root node at superblock_index+1
    // free space list for rest
            BTreeNode newsuperblock(BTREE_SUPERBLOCK,
                    superblock.info.keysize,
                    superblock.info.valuesize,
                    buffercache->GetBlockSize());
            newsuperblock.info.rootnode=superblock_index+1;
            newsuperblock.info.freelist=superblock_index+2;
            newsuperblock.info.numkeys=0;

            buffercache->NotifyAllocateBlock(superblock_index);

            rc=newsuperblock.Serialize(buffercache,superblock_index);

            if (rc) { 
                  return rc;
          }

          BTreeNode newrootnode(BTREE_ROOT_NODE,
              superblock.info.keysize,
              superblock.info.valuesize,
              buffercache->GetBlockSize());
          newrootnode.info.rootnode=superblock_index+1;
          newrootnode.info.freelist=superblock_index+2;
          newrootnode.info.numkeys=0;

          buffercache->NotifyAllocateBlock(superblock_index+1);

          rc=newrootnode.Serialize(buffercache,superblock_index+1);

          if (rc) { 
                  return rc;
          }

          for (SIZE_T i=superblock_index+2; i<buffercache->GetNumBlocks();i++) { 
                  BTreeNode newfreenode(BTREE_UNALLOCATED_BLOCK,
                    superblock.info.keysize,
                    superblock.info.valuesize,
                    buffercache->GetBlockSize());
                  newfreenode.info.rootnode=superblock_index+1;
                  newfreenode.info.freelist= ((i+1)==buffercache->GetNumBlocks()) ? 0: i+1;

                  rc = newfreenode.Serialize(buffercache,i);

                  if (rc) {
                        return rc;
                }

        }
}

  // OK, now, mounting the btree is simply a matter of reading the superblock 

return superblock.Unserialize(buffercache,initblock);
}

ERROR_T BTreeIndex::Detach(SIZE_T &initblock)
{
      return superblock.Serialize(buffercache,superblock_index);
}



//meat of lookup & update
ERROR_T BTreeIndex::LookupOrUpdateInternal(const SIZE_T &node,
     const BTreeOp op,
     const KEY_T &key,
     VALUE_T &value)
{
	BTreeNode b;
	ERROR_T rc;
	SIZE_T offset;
	KEY_T testkey;
	SIZE_T ptr;

	rc= b.Unserialize(buffercache,node);

	if (rc!=ERROR_NOERROR) {return rc;} //if unserialize errs, return it
	
	switch (b.info.nodetype) { 
		case BTREE_ROOT_NODE://traverse if root or interior
		case BTREE_INTERIOR_NODE:
    		// Scan through key/ptr pairs
    		//and recurse if possible
    		for (offset=0;offset<b.info.numkeys;offset++) { 
				rc=b.GetKey(offset,testkey);
				if (rc) {  return rc; }
				if (key<testkey || key==testkey) {
					// OK, so we now have the first key that's larger
					// so we ned to recurse on the ptr immediately previous to 
					// this one, if it exists
					rc=b.GetPtr(offset,ptr);
					if (rc) { return rc; }
			
					return LookupOrUpdateInternal(ptr,op,key,value);
     			}
    		}
    		// if we got here, we need to go to the next pointer, if it exists
			if (b.info.numkeys>0) { 
				rc=b.GetPtr(b.info.numkeys,ptr);
				if (rc) { return rc; }
		
				return LookupOrUpdateInternal(ptr,op,key,value);
			} else {
				// There are no keys at all on this node, so nowhere to go
				return ERROR_NONEXISTENT;
			}
			break;
  		case BTREE_LEAF_NODE:
    		// Scan through keys looking for matching value
			for (offset=0;offset<b.info.numkeys;offset++) { 
				rc=b.GetKey(offset,testkey);
				if (rc) {  return rc; }
				if (testkey==key) { 
					if (op==BTREE_OP_LOOKUP) { 
						return b.GetVal(offset,value);
					}//BTREE_OP_LOOKUP
					else { 
						// cout << "GOT TO UPDATE" << endl;	
						rc = b.SetVal(offset,value);//set the value
						if (rc) {return rc;}//if unsuccessful, get out
						return b.Serialize(buffercache, node);// write the updated node
					}// BTREE_OP_UPDATE
				}
			}
			return ERROR_NONEXISTENT;
			break;
  		default:
    		// We can't be looking at anything other than a root, internal, or leaf
    		return ERROR_INSANE;
    		break;
  	}  
  	return ERROR_INSANE;
}

static ERROR_T PrintNode(ostream &os, SIZE_T nodenum, BTreeNode &b, BTreeDisplayType dt)
{
      KEY_T key;
      VALUE_T value;
      SIZE_T ptr;
      SIZE_T offset;
      ERROR_T rc;
      unsigned i;

      if (dt==BTREE_DEPTH_DOT) { 
            os << nodenum << " [ label=\""<<nodenum<<": ";
    } else if (dt==BTREE_DEPTH) {
            os << nodenum << ": ";
    } else {
    }

    switch (b.info.nodetype) { 
      case BTREE_ROOT_NODE:
      case BTREE_INTERIOR_NODE:
      if (dt==BTREE_SORTED_KEYVAL) {
      } else {
          if (dt==BTREE_DEPTH_DOT) { 
          } else { 
                os << "Interior: ";
        }
        for (offset=0;offset<=b.info.numkeys;offset++) { 
                rc=b.GetPtr(offset,ptr);
                if (rc) { return rc; }
                os << "*" << ptr << " ";
        // Last pointer
                if (offset==b.info.numkeys) break;
                rc=b.GetKey(offset,key);
                if (rc) {  return rc; }
                for (i=0;i<b.info.keysize;i++) { 
                      os << key.data[i];
              }
              os << " ";
      }
}
break;
case BTREE_LEAF_NODE:
if (dt==BTREE_DEPTH_DOT || dt==BTREE_SORTED_KEYVAL) { 
} else {
  os << "Leaf: ";
}
for (offset=0;offset<b.info.numkeys;offset++) { 
  if (offset==0) { 
        // special case for first pointer
        rc=b.GetPtr(offset,ptr);
        if (rc) { return rc; }
        if (dt!=BTREE_SORTED_KEYVAL) { 
              os << "*" << ptr << " ";
      }
}
if (dt==BTREE_SORTED_KEYVAL) { 
        os << "(";
}
rc=b.GetKey(offset,key);
if (rc) {  return rc; }
for (i=0;i<b.info.keysize;i++) { 
        os << key.data[i];
}
if (dt==BTREE_SORTED_KEYVAL) { 
        os << ",";
} else {
        os << " ";
}
rc=b.GetVal(offset,value);
if (rc) {  return rc; }
for (i=0;i<b.info.valuesize;i++) { 
        os << value.data[i];
}
if (dt==BTREE_SORTED_KEYVAL) { 
        os << ")\n";
} else {
        os << " ";
}
}
break;
default:
if (dt==BTREE_DEPTH_DOT) { 
  os << "Unknown("<<b.info.nodetype<<")";
} else {
  os << "Unsupported Node Type " << b.info.nodetype ;
}
}
if (dt==BTREE_DEPTH_DOT) { 
    os << "\" ]";
}
return ERROR_NOERROR;
}

//operations
ERROR_T BTreeIndex::Lookup(const KEY_T &key, VALUE_T &value)
{
	if (key.length != superblock.info.keysize){
		return ERROR_SIZE;
	}// check user input
	else {
  		return LookupOrUpdateInternal(superblock.info.rootnode, BTREE_OP_LOOKUP, key, value);
  	}// execute the lookup
}

ERROR_T BTreeIndex::Update(const KEY_T &key, const VALUE_T &value)
{
// 	cout<<"superblock.info.keysize: "<<superblock.info.keysize<<endl;
// 	cout<<"key.length: "<<key.length<<endl;
// 	cout<<"superblock.info.valuesize: "<<superblock.info.valuesize<<endl;
// 	cout<<"value.length: "<<value.length<<endl;
	if (key.length != superblock.info.keysize || value.length != superblock.info.valuesize){
		return ERROR_SIZE;
	}// check user input 
	else {
   		return LookupOrUpdateInternal(superblock.info.rootnode, BTREE_OP_UPDATE, key, (VALUE_T&) value);
   	}// execute the update
}

ERROR_T BTreeIndex::Insert(const KEY_T &key, const VALUE_T &value)
{
      return InsertInternal(superblock.info.rootnode, key, value);
}

ERROR_T BTreeIndex::InsertInternal(const SIZE_T &node, const KEY_T &key, const VALUE_T &value)

{
        BTreeNode b; 
        ERROR_T rc;
        SIZE_T offset;
        KEY_T testkey;
        SIZE_T ptr;
        SIZE_T newptr;
        SIZE_T numInteriorSlots;
        SIZE_T numLeafSlots;

        rc = b.Unserialize(buffercache,node);

        if (rc) { return rc; }

        // cout << "Node: " << node << ", key: " << key.data << ", val: " << value.data << endl;

        // CHECK HERE IF KEYSIZE AND VALUESIZE ARE VALID
        if (b.info.keysize != key.length || b.info.valuesize != value.length) {
                return ERROR_SIZE;
        } 

        switch (b.info.nodetype) { 

                // if a root node is passed in, check if it has any children
                // if not, create a leaf and insert value
                // if it does, recurse -> same as for interior nodes (so no break)
                case BTREE_ROOT_NODE:
                if (b.info.numkeys == 0) {
                        rc = CreateLeaf(key, value, newptr); //newptr gets assigned in CreateLeaf
                        if (rc) {  return rc; }
                        b.info.numkeys++;
                        b.SetKey(0, key);
                        b.SetPtr(0, newptr);
                        rc = b.Serialize(buffercache, node); 
                        if (rc) { return rc; }
                        return ERROR_NOERROR;
                }
                case BTREE_INTERIOR_NODE: //this case doesn't insert, it's trying to find correct leaf
                numInteriorSlots = b.info.GetNumSlotsAsInterior();
                for (offset = 0; offset < b.info.numkeys; offset++) { 
                        rc=b.GetKey(offset,testkey); //testkey now holds value of node's key at offset
                        if (rc) { return rc; }
                        if (key < testkey || key == testkey) {
                                rc = b.GetPtr(offset,ptr);
                                if (rc) { return rc; }
                                rc = InsertInternal(ptr, key, value);
                                if (rc == WARNING_SPLIT) {
                                        rc = Split(b, ptr, offset, node); //takes parent and child and parent's offset
                                        if (rc) { return rc; }
                                        if (b.info.numkeys == numInteriorSlots) { //SPLIT INTERIOR OR ROOT NODE CASE
                                                if (b.info.nodetype == BTREE_ROOT_NODE) {
                                                        return SplitRoot(b, node); //SPLIT ROOT NODE AAAHHH
                                                }
                                                else {
                                                        return WARNING_SPLIT; //TELL NODE TO SPLIT
                                                }
                                        }
                                        return rc;
                                }        
                                return rc;
                        }
                }
                // if we got here, we need to go to the rightmost pointer, if it exists
                if (b.info.numkeys > 0) { 
                        rc = b.GetPtr(b.info.numkeys, ptr); //b.info.numkeys is the index of the rightmost ptr
                        if (rc) { return rc; }
                        if (ptr != 0) { //if the right pointer does exist
                                rc = InsertInternal(ptr, key, value);
                                if (rc == WARNING_SPLIT) {
                                        rc = Split(b, ptr, offset, node); //takes parent and child and parent's offset
                                        if (rc) { return rc; }
                                        if (b.info.numkeys == numInteriorSlots) { //SPLIT INTERIOR OR ROOT NODE CASE
                                                if (b.info.nodetype == BTREE_ROOT_NODE) {
                                                        return SplitRoot(b, node); //SPLIT ROOT NODE AAAHHH
                                                }
                                                else {
                                                        return WARNING_SPLIT; //TELL NODE TO SPLIT
                                                }
                                        }
                                        return rc;
                                }
                                return rc;
                        }
                        else { //if the right pointer and leaf doesn't exist, create a leaf and pointer
                                rc = CreateLeaf(key, value, newptr);
                                if (rc) { return rc; }
                                b.SetPtr(b.info.numkeys, newptr);
                                rc = b.Serialize(buffercache, node); 
                                if (rc) { return rc; }
                                return ERROR_NOERROR;
                        }
                } 
                else {
                        // There are no keys at all on this node, so nowhere to go
                        return ERROR_NONEXISTENT;
                }
                break;
                case BTREE_LEAF_NODE:
                numLeafSlots = b.info.GetNumSlotsAsLeaf();
                if (b.info.numkeys < numLeafSlots) {
                        // insert key and value here
                        rc = InsertKeyValueIntoLeaf(b, key, value);
                        if (rc) { return rc; }
                        rc = b.Serialize(buffercache, node);
                        // cout << "inserted keyval" << endl;
                        if (rc) { return rc; }
                        if (b.info.numkeys == numLeafSlots) { //SPLIT LEAF NODE CASE
                                return WARNING_SPLIT; //TELL NODE TO SPLIT
                        }
                        return ERROR_NOERROR;
                }
                else { //this should never be called
                        return ERROR_INSANE;
                }
        }
        return ERROR_INSANE;
}

ERROR_T BTreeIndex::SplitRoot(BTreeNode &oldroot, const SIZE_T &oldrootAddress_tmp) 
{
        // cout << "SPLITTING ROOT" << endl;
        ERROR_T rc;
        SIZE_T newroot;
        BTreeNode newrootdata;
        SIZE_T oldrootAddress;

        oldrootAddress = oldrootAddress_tmp; //cast to a SIZE_T from const SIZE_T
        // create new root node
        newrootdata = BTreeNode(BTREE_ROOT_NODE, oldroot.info.keysize, oldroot.info.valuesize, oldroot.info.blocksize); 
        rc = AllocateNode(newroot); //allocate space for root node
        if (rc) { return rc; }
        oldroot.info.nodetype = BTREE_INTERIOR_NODE; //change type of old root node
        newrootdata.SetPtr(0, oldrootAddress); //set pointer to old root (now interior)

        superblock.info.rootnode = newroot;
        rc = superblock.Serialize(buffercache, superblock_index);
        if (rc) { return rc; }

        return SplitInterior(newrootdata, oldroot, newroot, oldrootAddress, 0);
}

ERROR_T BTreeIndex::Split(BTreeNode &parent, SIZE_T &child, SIZE_T &parentoffset, const SIZE_T &parentAddress) 
{
        ERROR_T rc;
        BTreeNode node;

        rc = node.Unserialize(buffercache, child);
        switch (node.info.nodetype) {
                case BTREE_LEAF_NODE:
                return SplitLeaf(parent, node, parentAddress, child, parentoffset);
                case BTREE_INTERIOR_NODE:
                return SplitInterior(parent, node, parentAddress, child, parentoffset);
        }
        return ERROR_INSANE;
}

ERROR_T BTreeIndex::SplitInterior(BTreeNode &parent, BTreeNode &childnode, const SIZE_T &parentAddress, SIZE_T &child, SIZE_T parentoffset) 
{
        // cout << "SPLITTING INTERIOR" << endl;
        ERROR_T rc;
        BTreeNode newptrdata;
        SIZE_T offset;
        SIZE_T newptr;
        KEY_T tmpkey;
        SIZE_T tmpptr;
        SIZE_T ii;

        offset = (childnode.info.numkeys / 2) + 1; //find where to split
        // cout << "offset: " << offset << endl;
        // create new interior node
        newptrdata = BTreeNode(BTREE_INTERIOR_NODE, childnode.info.keysize, childnode.info.valuesize, childnode.info.blocksize); 
        rc = AllocateNode(newptr); //allocate space for new interior node
        if (rc) { return rc; }

        // cout << "numkeys old: " << childnode.info.numkeys << endl;
        for (ii = offset; ii < childnode.info.numkeys; ii++) { //Move stuff into new node
                childnode.GetKey(ii, tmpkey);
                childnode.GetPtr(ii, tmpptr);
                rc = InsertKeyPtrIntoInterior(newptrdata, tmpkey, tmpptr); //Insert key and ptr
                if (rc) { return rc; }
        }
        //add rightmost pointer of previously unsplit left node to end of new right node
        childnode.GetPtr(childnode.info.numkeys, tmpptr);
        newptrdata.SetPtr(newptrdata.info.numkeys, tmpptr);

        // this condition handles case where we aren't splitting rightmost childnode - find offset in parent node
        if (parentoffset < parent.info.numkeys) {
                //get highest key of left childnode and insert this key into the parent
                childnode.GetKey(offset - 1, tmpkey);
                rc = InsertKeyPtrIntoInterior(parent, tmpkey, child);
                if (rc) { return rc; }
                //set ptr of next key in parent to newly created (right) childnode
                parent.SetPtr(parentoffset + 1, newptr);
        }
        // if we are splitting rightmost childnode, we already know where to put the key in the parent node
        else {
                parent.info.numkeys++; //add space for extra key
                //get highest key of left childnode and insert this key and ptr at end of parent
                childnode.GetKey(offset - 1, tmpkey);
                parent.SetKey(parent.info.numkeys - 1, tmpkey);
                parent.SetPtr(parent.info.numkeys - 1, child);
                //set rightmost pointer to newly created childnode
                parent.SetPtr(parent.info.numkeys, newptr);
        }

        //set number of keys to how many we care about - get rid of last key because we insert it one level higher
        childnode.info.numkeys = offset - 1; 
        // cout << "numkeys new: " << childnode.info.numkeys << endl;

        childnode.Serialize(buffercache, child);
        newptrdata.Serialize(buffercache, newptr);
        parent.Serialize(buffercache, parentAddress);

        // cout << "parent.info.numkeys" << parent.info.numkeys << endl;

        return ERROR_NOERROR;
}

ERROR_T BTreeIndex::SplitLeaf(BTreeNode &parent, BTreeNode &leaf, const SIZE_T &parentAddress, SIZE_T &child, SIZE_T parentoffset) 
{
        // cout << "SPLITTING LEAF" << endl;
        BTreeNode newptrdata;
        SIZE_T newptr;
        SIZE_T offset;
        SIZE_T ii;
        KEY_T keytosplit;
        VALUE_T valuetosplit;
        KEY_T tmpkey;
        VALUE_T tmpvalue;
        ERROR_T rc;

        offset = (leaf.info.numkeys / 2) + 1; //find where to split
        leaf.GetKey(offset, keytosplit);
        // cout << "key: " << keytosplit.data << ", offset: " << offset << ", leaf.info.numkeys: " << leaf.info.numkeys << endl;
        
        leaf.GetVal(offset, valuetosplit);
        rc = CreateLeaf(keytosplit, valuetosplit, newptr); //Create new leaf called newptr
        if (rc) { return rc; }
        newptrdata.Unserialize(buffercache, newptr);
        if (rc) { return rc; }
        for (ii = offset + 1; ii < leaf.info.numkeys; ii++) { //Move stuff into new leaf (newptr)
                leaf.GetKey(ii, tmpkey);
                leaf.GetVal(ii, tmpvalue);
                rc = InsertKeyValueIntoLeaf(newptrdata, tmpkey, tmpvalue); //insert key and value
                if (rc) { return rc; } 
        }
        // cout << "inserted all leaves" << endl;
        leaf.info.numkeys = offset; //set number of keys to how many we care about
        // cout << "numkeys" << leaf.info.numkeys << endl;

        // this condition handles case where we aren't splitting rightmost leaf - find offset in interior node
        if (parentoffset < parent.info.numkeys) {
                // cout << "dealing with parent" << endl;
                //get highest key of left leaf and insert this key into the parent
                leaf.GetKey(offset - 1, tmpkey);
                rc = InsertKeyPtrIntoInterior(parent, tmpkey, child);
                if (rc) { return rc; }
                //set ptr of next key in interior to newly created (right) leaf
                parent.SetPtr(parentoffset + 1, newptr);
        }
        // if we are splitting rightmost leaf, we already know where to put the key in the interior node
        else {
                // cout << "dealing with parent" << endl;
                parent.info.numkeys++; //add space for extra key
                //get highest key of left leaf and insert this key and ptr at end of parent
                leaf.GetKey(offset - 1, tmpkey);
                parent.SetKey(parent.info.numkeys - 1, tmpkey);
                parent.SetPtr(parent.info.numkeys - 1, child);
                //set rightmost pointer to newly created leaf
                parent.SetPtr(parent.info.numkeys, newptr);
        }

        leaf.Serialize(buffercache, child);
        newptrdata.Serialize(buffercache, newptr);
        parent.Serialize(buffercache, parentAddress);

        // cout << "parent.info.numkeys" << parent.info.numkeys << endl;

        return ERROR_NOERROR;
}

ERROR_T BTreeIndex::InsertKeyPtrIntoInterior(BTreeNode &b, const KEY_T &key, SIZE_T &ptr) 
{
        // cout << "inserting" << endl;
        SIZE_T offset;
        KEY_T testkey;
        SIZE_T testptr;
        ERROR_T rc;
        SIZE_T oldnumkeys;

        oldnumkeys = b.info.numkeys;
        b.info.numkeys++; 

        // if it is a brand new node (nothing in it)
        if (oldnumkeys == 0) {
                // cout << "inserting into empty node" << endl;
                b.SetKey(0, key);
                b.SetPtr(0, ptr);
        }
        else { //if there is already stuff in the node
                // first, move over right most pointer so it doesn't get overwritten
                rc = b.GetPtr(oldnumkeys, testptr);
                if (rc) { return rc; }
                b.SetPtr(b.info.numkeys, testptr);
                // cout << "oldnumkeys: " << oldnumkeys << endl;

                // then move everything else into the correct place
                for (offset = oldnumkeys; offset > 0; offset--) { 
                        rc = b.GetKey(offset - 1, testkey); //testkey now holds value of node's key at offset - 1
                        if (rc) { return rc; }
                        // cout << "testkey: " << testkey.data << endl;
                        if (testkey < key) {
                                // cout << "key is greater than testkey, key: " << key.data << endl;
                                b.SetKey(offset, key);
                                b.SetPtr(offset, ptr);
                                break;
                        }
                        else if (key == testkey) {
                                // cout << "key is equal to testkey, key: " << key.data << endl;
                                return ERROR_CONFLICT;
                        }
                        else {
                                // cout << "key is less than testkey, key: " << key.data << endl;
                                // move things over to the right
                                rc = b.GetPtr(offset - 1, testptr);
                                if (rc) { return rc; }
                                b.SetKey(offset, testkey);
                                b.SetPtr(offset, testptr);
                                if (offset == 1) { //accounts for last case, when inserting at beginning of node
                                        b.SetKey(0, key);
                                        b.SetPtr(0, ptr);
                                }
                        }                
                } 
        }       
        return ERROR_NOERROR;
}

ERROR_T BTreeIndex::InsertKeyValueIntoLeaf(BTreeNode &b, const KEY_T &key, const VALUE_T &value) 
{
        SIZE_T offset;
        KEY_T testkey;
        VALUE_T testvalue;
        ERROR_T rc;

        SIZE_T oldnumkeys = b.info.numkeys;
        b.info.numkeys++;
        for (offset = oldnumkeys; offset > 0; offset--) { 
                rc = b.GetKey(offset - 1, testkey); //testkey now holds value of node's key at offset - 1
                if (rc) { return rc; }
                // cout << "testkey: " << testkey.data << endl;
                if (testkey < key) {
                        // cout << "key is greater than testkey, key: " << key.data << endl;
                        b.SetKey(offset, key);
                        b.SetVal(offset, value);
                        break;
                }
                else if (key == testkey) {
                        // cout << "key is equal to testkey, key: " << key.data << endl;
                        return ERROR_CONFLICT;
                }
                else {
                        // cout << "key is less than testkey, key: " << key.data << endl;
                        // move things over to the right
                        rc = b.GetVal(offset - 1, testvalue);
                        if (rc) { return rc; }
                        b.SetKey(offset, testkey);
                        b.SetVal(offset, testvalue);
                        if (offset == 1) { //accounts for last case, when inserting at beginning of leaf
                                b.SetKey(0, key);
                                b.SetVal(0, value);
                        }
                }                
        }     
        return ERROR_NOERROR;
}

ERROR_T BTreeIndex::CreateLeaf(const KEY_T &key, const VALUE_T &value, SIZE_T &newptr) 
{
        BTreeNode root;
        ERROR_T rc;
        BTreeNode newleaf;

        rc = root.Unserialize(buffercache,superblock.info.rootnode);
        if (rc) { return rc; }
        AllocateNode(newptr);
        newleaf = BTreeNode(BTREE_LEAF_NODE, root.info.keysize, root.info.valuesize, root.info.blocksize);
        newleaf.info.numkeys++;
        newleaf.SetKey(0, key);
        newleaf.SetVal(0, value);
        rc = newleaf.Serialize(buffercache, newptr);
        if (rc) { return rc; }
        return ERROR_NOERROR;
}


ERROR_T BTreeIndex::Delete(const KEY_T &key)
{
  // This is optional extra credit 
  //
  // 
      return ERROR_UNIMPL;
}


// DEPTH first traversal
// DOT is Depth + DOT format
ERROR_T BTreeIndex::DisplayInternal(const SIZE_T &node,
    ostream &o,
    BTreeDisplayType display_type) const
{
      KEY_T testkey;
      SIZE_T ptr;
      BTreeNode b;
      ERROR_T rc;
      SIZE_T offset;

      rc= b.Unserialize(buffercache,node);

      if (rc!=ERROR_NOERROR) { 
            return rc;
    }

    rc = PrintNode(o,node,b,display_type);

    if (rc) { return rc; }

    if (display_type==BTREE_DEPTH_DOT) { 
            o << ";";
    }

    if (display_type!=BTREE_SORTED_KEYVAL) {
            o << endl;
    }

    switch (b.info.nodetype) { 
      case BTREE_ROOT_NODE:
      case BTREE_INTERIOR_NODE:
      if (b.info.numkeys>0) { 
          for (offset=0;offset<=b.info.numkeys;offset++) { 
                rc=b.GetPtr(offset,ptr);
                if (rc) { return rc; }
                if (display_type==BTREE_DEPTH_DOT) { 
                      o << node << " -> "<<ptr<<";\n";
              }
              rc=DisplayInternal(ptr,o,display_type);
              if (rc) { return rc; }
      }
}
return ERROR_NOERROR;
break;
case BTREE_LEAF_NODE:
return ERROR_NOERROR;
break;
default:
if (display_type==BTREE_DEPTH_DOT) { 
} else {
  o << "Unsupported Node Type " << b.info.nodetype ;
}
return ERROR_INSANE;
}

return ERROR_NOERROR;
}

ERROR_T BTreeIndex::Display(ostream &o, BTreeDisplayType display_type) const
{
      ERROR_T rc;
      if (display_type==BTREE_DEPTH_DOT) { 
            o << "digraph tree { \n";
    }
    rc=DisplayInternal(superblock.info.rootnode,o,display_type);
    if (display_type==BTREE_DEPTH_DOT) { 
            o << "}\n";
    }
    return ERROR_NOERROR;
}




ERROR_T BTreeIndex::SanityCheck() const
{
  // Is it a tree? -- check for cycles (if unexplored edge leads to visited node before leaves)
  // Is it in order? -- in-order traversal, then check if they're in order
  // Is it balanced? -- from root, ensure difference in height of each branch is <=1. iterate.
  // Does each node have a valid use ratio?
  return ERROR_UNIMPL;
}



ostream & BTreeIndex::Print(ostream &os) const
{
  // WRITE ME
      return os;
}




