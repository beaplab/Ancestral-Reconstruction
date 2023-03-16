library(phytools)

input_tree_path <- "/home/agalvez/data/eukprot/run_dollop/to_resolve.txt"
output_tree_path <- "/home/agalvez/data/eukprot/run_dollop/2_resolved_dollop.tree"

tree <- read.newick(file = input_tree_path)

resolved_tree <- multi2di(tree, random = TRUE)

write.tree(resolved_tree, file = output_tree_path)
