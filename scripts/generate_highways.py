import argparse
import random
from ete3 import Tree

def get_all_nodes(tree):
    """Return a list of all nodes (internal and leaves) in the tree."""
    return tree.get_descendants("postorder") + [tree]

def get_valid_pairs(nodes, min_distance):
    """Return pairs of nodes that are at least min_distance apart."""
    valid_pairs = []
    for i in range(len(nodes)):
        for j in range(i + 1, len(nodes)):
            if nodes[i].get_distance(nodes[j]) >= min_distance:
                valid_pairs.append((nodes[i], nodes[j]))
    return valid_pairs

def select_random_pairs(tree_file, num_pairs, min_distance, output_file):
    """Select random node pairs and write to a file."""
    tree = Tree(tree_file, format=1)
    nodes = get_all_nodes(tree)
    valid_pairs = get_valid_pairs(nodes, min_distance)

    if len(valid_pairs) < num_pairs:
        raise ValueError(f"Only {len(valid_pairs)} valid pairs found, but {num_pairs} requested.")

    selected_pairs = random.sample(valid_pairs, num_pairs)

    with open(output_file, "w") as f:
        for i, (node1, node2) in enumerate(selected_pairs):
            f.write(f"{node1.name if node1.name else node1}, {node2.name if node2.name else node2}\n")
            if i == (num_pairs // 2) - 1:  # Insert separator after first half
                f.write("#######################\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Select random node pairs from a tree.")
    parser.add_argument("tree_file", help="Input Newick tree file")
    parser.add_argument("num_pairs", type=int, help="Number of node pairs to select")
    parser.add_argument("min_distance", type=int, help="Minimum distance between selected nodes")
    parser.add_argument("output_file", help="Output file to save the selected pairs")

    args = parser.parse_args()
    select_random_pairs(args.tree_file, args.num_pairs, args.min_distance, args.output_file)
