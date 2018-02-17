package net.apjanke.mprojectnavigator.swing;

import com.mathworks.hg.peer.UITreeNode;
import com.mathworks.hg.peer.UITreePeer;

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
    public void remove(UITreeNode parent, UITreeNode node) {
        if (null == parent || null == node) {
            return;
        }
        int childIndex = -1;
        for (int i = 0; i < parent.getChildCount(); i++) {
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

    public void addSingle(UITreeNode parent, UITreeNode child) {
        add(parent, new UITreeNode[] { child });
    }

    public void add(UITreeNode parent, UITreeNode child) {
        add(parent, new UITreeNode[] { child });
    }

    /**
     * addMulti() is a wrapper for add() that always calls the add(UITreeNode, UITreeNode[])
     * variant, and not add(UITreeNode, UITreeNode), which may be buggy.
     * @param parent
     * @param child
     */
    public void addMulti(UITreeNode parent, UITreeNode child[]) {
        add(parent, child);
    }

    public void addMulti(UITreeNode parent, UITreeNode child) {
        add(parent, new UITreeNode[] { child });
    }
}
