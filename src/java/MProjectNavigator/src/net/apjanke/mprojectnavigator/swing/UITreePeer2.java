package net.apjanke.mprojectnavigator.swing;

import com.mathworks.hg.peer.UITreeNode;
import com.mathworks.hg.peer.UITreePeer;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Modified UITreePeer
 *
 * This class exists to work around apparent bugs in Matlab's UITreePeer class. Specifically,
 * in UITreePeer:
 * <ul>
 *     <li>The remove() methods do not fire nodesWereRemoved() events (although
 *     removeAllChildren() does).</li>
 *     <li>The single-node add() method does not fire nodesWereAdded().</li>
 * </ul>
 *
 * I observed this issue in Matlab R2016b and R2018a. It might be resolved in future releases,
 * in which case this class will not be necessary.
 */
public class UITreePeer2 extends UITreePeer {

    //-------------------------------------------------
    // Bug Fixes

    /**
     * This method is overridden to work around an apparent bug in UITreePeer where
     * it does not raise a nodesWereRemoved() event when removing single child nodes.
     * @param parent
     * @param node
     */
    public void remove(UITreeNode parent, UITreeNode node) {
        if (null == parent || null == node) {
            return;
        }
        int childIndex = -1;
        int nChildren = parent.getChildCount();
        for (int i = 0; i < nChildren; i++) {
            if (parent.getChildAt(i) == node) {
                childIndex = i;
                break;
            }
        }
        if (childIndex == -1) {
            throw new IllegalStateException("Could not locate node "+node
                +" as a child of node "+parent);
        }
        parent.remove(node);
        nodesWereRemoved(parent, new int[] { childIndex });
    }

    /**
     * This method is overridden to work around an apparent bug in UITreePeer where it
     * does not raise a nodesWereAdded() event when adding a single child.
     * @param parent
     * @param child
     */
    public void add(UITreeNode parent, UITreeNode child) {
        add(parent, new UITreeNode[] { child });
    }

    //-------------------------------------------------
    // Enhancements

    /**
     * Remove multiple nodes by identity. This method is an optimization that allows
     * multiple removals to be coalesced and raise only a single nodesWereRemoved() event.
     * @param parent node to remove children from
     * @param nodes Nodes to remove
     */
    public void remove(UITreeNode parent, UITreeNode[] nodes) {
        if (null == parent || null == nodes) {
            return;
        }

        // Locate the nodes to be removed under the parent
        List<Integer> indexes = new ArrayList<>();
        for (int i = 0; i < nodes.length; i++) {
            int childIndex = -1;
            int nChildren = parent.getChildCount();
            for (int j = 0; j < nChildren; j++) {
                if (parent.getChildAt(j) == nodes[i]) {
                    childIndex = i;
                    break;
                }
            }
            if (childIndex == -1) {
                throw new IllegalStateException("Could not locate node "+nodes[i]
                        +" as a child of node "+parent);
            }
            indexes.add(childIndex);
        }

        // Remove them
        int[] ix = new int[indexes.size()];
        for (int i = 0; i < ix.length; i++) {
            ix[i] = indexes.get(i);
        }
        Arrays.sort(ix);
        remove(parent, ix);
    }


    /**
     * Remove multiple nodes by their index. This method is an optimization that allows
     * multiple removals to be coalesced and raise only a single nodesWereRemoved() event.
     * @param parent node to remove children from
     * @param index child indexes to be removed; must be in sorted order
     */
    public void remove(UITreeNode parent, int[] index) {
        if (null == parent || null == index) {
            return;
        }
        if (index.length == 0) {
            return;
        }
        for (int i = index.length - 1; i >= 0; i--) {
            parent.remove(index[i]);
        }
        nodesWereRemoved(parent, index);
    }



}
