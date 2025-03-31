import argparse
import random

def read_node_pairs(pair_file):
    """Reads node pairs from the file, ignoring separator lines."""
    pairs = []
    with open(pair_file, "r") as f:
        for line in f:
            line = line.strip()
            if line and "#" not in line:
                pairs.append(line.split(", "))
            elif "#" in line:
                break
    return pairs

def generate_h_params(pairs, t_value, factors):
    """Generates -h parameters with rates based on -t."""
    return [f"-h {p1}:{p2}:{factor * t_value}" for (p1, p2), factor in zip(pairs, factors)]

def generate_script(executable, tree_file, num_results, num_reps, pairs_file, d_values, t_values, l_values, lambdas, post_script, output_script, basepath):
    """Generates a shell script with simulation commands."""
    pairs = read_node_pairs(pairs_file)

    if not (len(d_values) == len(t_values) == len(l_values)):
        raise ValueError("The number of -d, -t, and -l values must be the same.")

    rate_factors = [1, 10, 50]
    factors = random.choices(rate_factors, k=len(pairs))
    with open(output_script, "w") as f:
        f.write("#!/bin/bash\n")  # Shebang for shell script

        for la in lambdas:
            f.write(f"\n# lambda {la}\n")
            for d, t, l in zip(d_values, t_values, l_values):
                f.write(f"\n# d, t, l = ({d}, {t}, {l})\n")
                for rep in range(0, num_reps):
                    h_params = generate_h_params(pairs, t, factors)
                    h_str = " ".join(h_params)
                    output_dir = f"sim_d{d}_t{t}_l{l}_lambda{la}_rep{rep}"  # Dynamic output directory name

                    seed = random.randint(0, (2**16) - 1)

                    cmd = (f"{executable} -i {tree_file} -n {num_results} {h_str} "
                           f"-d {d} -t {t} -l {l} -p {output_dir} -b l:0:0.0 --lambda {la} -s {seed} # rep {rep}\n")

                    f.write(cmd)
                    f.write(f"python {post_script} {output_dir} {basepath}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a shell script with simulation commands.")
    parser.add_argument("-e", "--executable", required=True, help="Path to the dtlh_simulator executable")
    parser.add_argument("-i", "--tree_file", required=True, help="Input Newick tree file")
    parser.add_argument("-n", "--num_results", type=int, required=True, help="Number of results to generate (-n parameter)")
    parser.add_argument("-r", "--reps", type=int, default=1, help="Number of repetitions")
    parser.add_argument("-p", "--pairs_file", required=True, help="File containing node pairs")
    parser.add_argument("-d", "--d_values", nargs="+", type=float, required=True, help="List of -d values")
    parser.add_argument("-t", "--t_values", nargs="+", type=float, required=True, help="List of -t values")
    parser.add_argument("-l", "--l_values", nargs="+", type=float, required=True, help="List of -l values")
    parser.add_argument("-x", "--lambda_values", nargs="+", type=float, required=True, help="List of --lambda values")
    parser.add_argument("-y", "--post_script", required=True, help="Path to the family.txt script")
    parser.add_argument("-o", "--output_script", required=True, help="Output shell script file")
    parser.add_argument("-b", "--basepath", default='.', help="Basepath for the family files to prepend")

    args = parser.parse_args()

    generate_script(args.executable, args.tree_file, args.num_results, args.reps, args.pairs_file,
                    args.d_values, args.t_values, args.l_values, args.lambda_values, args.post_script, args.output_script, args.basepath)
