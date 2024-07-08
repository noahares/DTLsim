# DTLsim
A command line utility for generating gene trees under the DTL model with "highways"

**This tool is still in development and with a rather specific use-case in mind. The simulation of the model works well as far as I can tell, but you still ought to be cautions.**

For more on the DTL model see for example [this paper about GeneRax](https://academic.oup.com/mbe/article/37/9/2763/5851843) [^generax]

Highways are pairs of species that have a vastly higher rate of HGTs happening between them.
An updated version of the DTL Model including Highways will be available soon.

## Usage

```
Usage: dtlh_simulator [OPTIONS] --species-tree <FILE>

Options:
        --help
            Display this help and exit.

    -i, --species-tree <FILE>
            Path to the species tree

    -p, --prefix <DIR>
            Prefix directory for the output files (default: $CWD)

        --redo
            Override existing output files

    -s, --seed <u64>
            RNG seed (default: 42)

    -n, --num-gene-families <usize>
            Number of gene families to generate (default: 100)

    -d, --duplication-rate <f32>
            Duplication rate (default: 0.1)

    -t, --transfer-rate <f32>
            Transfer rate (default: 0.1)

    -l, --loss-rate <f32>
            Loss rate (default: 0.1)

    -o, --root-origination <f32>
            Root origination rate (default: 1.0)

    -b, --branch-rate-modifier <MOD>...
            Individual values for DTL rates on specific species tree branches (format <type>:<branch_id>:<value> where type is one of {d, t, r, l, o})

    -h, --highway <HIGHWAY>...
            Defines a transfer highway between two species tree branches (format <source_id>:<target_id>:<probability>)

    -c, --transfer-constraint <CONSTR>
            Transfer constraint, either parent, dated or none (default: parent)

    -x, --post-transfer-loss <f32>
            Factor for changing the loss rate after receiving a gene via transfer (default: 1.0)
```
Most of the time, you want to specify at least `-d -t -l` to change the duplication, transfer and loss rates.

Highways and branch length modifiers can be specified multiple times.
The source and target branch ids are based on a post-order traversal of the input species tree.
After running the tool once, a `species_tree.nwk` file will be created in the output prefix which contains the ids (each node is annotated with <name>.<id>).
However, it might be easier to give names to nodes that you want to modify (if they not already have some).
Then you can substitute the branch ids for the node names in the argument list like:
`-h source:target:0.01` to create a highway between the nodes named `source` and `target`.

To reproduce and understand results, this tool also outputs a file named `event_counts.txt` in the output prefix containing for each gene family the number of duplications, transfers, losses, highways and speciations during the simulation.
Arriving at leaves of the species tree and terminating the simulation counts as a speciation.
**Importantly, these numbers are slightly of because nodes are deleted after a loss, so some previous events might no longer be observable.**
Another output file is `parameters.txt` which includes the commandline string the program was called with.

The main output are the `familyXXX.nwk` files containing the gene families.
Each file contains one gene tree.
Because this tool was written with [AleRax](https://github.com/BenoitMorel/AleRax) in mind, there is also a script `scripts/create_families_file.py` to create the `families.txt` input file.
Another script summarizes the event counts for all gene trees.

[^generax]: Benoit Morel, Alexey M Kozlov, Alexandros Stamatakis, Gergely J Szöllősi, GeneRax: A Tool for Species-Tree-Aware Maximum Likelihood-Based Gene  Family Tree Inference under Gene Duplication, Transfer, and Loss, Molecular Biology and Evolution, Volume 37, Issue 9, September 2020, Pages 2763–2774, https://doi.org/10.1093/molbev/msaa141
