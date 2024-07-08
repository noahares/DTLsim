import os
import re
import sys

def create_families_file(directory, output_file):
    # Collect all family numbers and their corresponding files
    family_numbers = []
    files_info = []

    for file in os.listdir(directory):
        # Use regex to extract the family number from the filename
        match = re.match(r"family(\d+)\.nwk", file)
        if match:
            family_number = match.group(1)
            family_numbers.append(family_number)
            files_info.append((family_number, file))

    # Determine the length of the longest family number
    max_length = max(len(num) for num in family_numbers) if family_numbers else 0

    # Write the header to the output file
    with open(output_file, 'w') as f:
        f.write("[FAMILIES]\n")

    families_list = []

    for family_number, file in files_info:
        file_path = os.path.join(directory, file)

        # Count the number of commas in the file
        with open(file_path, 'r') as f:
            content = f.read()
            comma_count = content.count(',')

        # Include the file if it contains more than 3 commas
        if comma_count > 1:
            family_entry = f"- family_{int(family_number):0{max_length}d}\ngene_tree = {file}\n"
            families_list.append(family_entry)
        else:
            print(f"Family {family_number} contains less than 3 nodes, skipping...")

    # Write the collected families to the output file
    with open(output_file, 'a') as f:
        f.writelines(families_list)

# Define the directory containing the .nwk files and the output file name
directory = sys.argv[1]
output_file = os.path.join(directory, 'families.txt')

# Create the families.txt file
create_families_file(directory, output_file)
