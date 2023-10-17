### Perl scripts

- **AfterPhylo.pl:** Manipulate trees after phylogenetic reconstruction.

- **Orthofinder_orthogroups_to_probabilities.pl:** Parse OrthoFinder (https://github.com/davidemms/OrthoFinder) orthogroups, sequence IDs and a directory of BLAST/DIAMOND results to produce presence probabilities for each species in each cluster using the empirical cumulative E value distribution.

- **PASTA_probabilities_to_binary.pl:** Convert probabilities in a PASTA file to binary values (all non-zero values are changed to 1).

- **add_counter_to_tree.pl:** Read a tree file, looking for characters matching "__". Replace each instance with a counter, starting from zero.

- **add_underscores_to_internal_nodes_paste_tree.pl:** Read tree file, replace internal node names with "__".

- **batch_interproscan.pl:** Run InterProScan to search Pfam domains in a directory of FASTA files.

- **combine_simulation_output.pl:** Go through a directory of Dollop or Bppancestor (https://github.com/BioPP) results for different simulations and produce one output file summarizing results for all simulations.

- **create_bpp_config_files.pl:** For each file in the input directory, modify the template to replace the string placeholder with the name of the file, and save the modified template to the output directory.

- **dollop_state_at_node.pl:** Parse the output of Dollop from the PHYLIP package (https://phylipweb.github.io/phylip/) to count the number of genes at each inferred ancestral node.

- **interproscan_to_binary_PASTA.pl:** Go through a directory of InterProScan (https://www.ebi.ac.uk/interpro/) results (ending in .tsv) and group together domains, outputting a binary PASTA format.

- **move_and_rename_batch_dollop.pl:** Copy PHYLIP Dollop output files from a set of input directories to a single output directory.

- **parse_bppancestor_probabilities.pl:** Read input of Bppancestor and summarize the number of ancestral genes present at each node.

- **remove_internal_node_names.pl:** Read a tree file and remove internal node names.

- **rename_PASTA_headers.pl:** Rename the headers of a PASTA file.

### R scripts

- **resolve_multifurcations_in_tree.R:** Transform all polytomies into a series of dichotomies. 

### Bash scripts

- **bash_dollop:** Create a directory for each input file inside the current directory and run PHYLIP Dollop with an input tree and printing states at all nodes of the tree.

### Simulated dataset: Input files 

- **bppancestor_input_simulations.zip:** Simulated dataset input data files for Bppancestor.

- **dollop_input_simulations.zip:**  Simulated dataset input data files for PHYLIP Dollop.

### Pfam domain content in the earliest eukaryotes: Input files

- **named_eukprot_binaries.zip:** Pfam domain content reconstruction input data files for Bppancestor.

- **dollop_input.phylip:** Pfam domain content reconstruction input data files for PHYLIP Dollop.

### Template file for Bppancestor and Bppml

- **template_bppancestor_config_file.conf:** Configuration template file for Bppancestor.

- **template_bppml_config_file.conf:** Configuration template file for Bppml.

### Tree files

- **tree_for_simulations.txt:** Simulated dataset input tree file.

- **tree_for_domains.txt:**  Pfam domain content reconstruction input tree file.
