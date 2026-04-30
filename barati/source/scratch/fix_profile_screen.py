import sys

file_path = 'c:/Users/sushi/Projects/Github/SoftwareTestingPro.github.io/barati/lib/screens/profile_screen.dart'
with open(file_path, 'r') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    # Check for the pattern around line 450 (which might be shifted)
    if '    );' in line and i > 400 and i < 500:
        if i + 1 < len(lines) and '  }' in lines[i+1] and 'Widget _buildLabel' in lines[i+3]:
             new_lines.append('    ),\n')
             new_lines.append('  );\n')
             continue
    new_lines.append(line)

with open(file_path, 'w') as f:
    f.writelines(new_lines)
