import sys

path = r'c:\Users\sushi\Projects\Github\SoftwareTestingPro.github.io\barati\source\lib\screens\home_screen.dart'
# I need to restore the file from a backup or known good state.
# Since I don't have a backup, I have to rely on the fact that I know what should be there.

# Wait, I can see the "Total Lines: 2445" which is much larger than before (1746).
# This means I duplicated the file or something.

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Let's find the FIRST Widget _buildMyApplicationsList
# And remove everything between line 1230 and that definition.

start_of_mess = 1230
definition_line = -1
for i in range(start_of_mess, len(lines)):
    if 'Widget _buildMyApplicationsList({bool isPast = false})' in lines[i]:
        definition_line = i
        break

if definition_line != -1:
    new_lines = lines[:1230] + lines[definition_line:]
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print("Fixed mess")
else:
    print("Could not find definition")
