import sys
# Initialize counters
total_D = 0
total_T = 0
total_L = 0
total_H = 0
total_S = 0

# Read the file
with open(sys.argv[1], 'r') as file:
    for line in file:
        # Remove newline and extra spaces
        line = line.strip()

        # Split the line on the tab character
        _, counts = line.split('\t')

        # Extract the counts
        parts = counts.split(', ')
        for part in parts:
            if part.startswith('D:'):
                total_D += int(part.split(': ')[1])
            elif part.startswith('T:'):
                total_T += int(part.split(': ')[1])
            elif part.startswith('L:'):
                total_L += int(part.split(': ')[1])
            elif part.startswith('H:'):
                total_H += int(part.split(': ')[1])
            elif part.startswith('S:'):
                total_S += int(part.split(': ')[1])

# Output the totals
print(f'Total D: {total_D}')
print(f'Total T: {total_T}')
print(f'Total L: {total_L}')
print(f'Total H: {total_H}')
print(f'Total S: {total_S}')
