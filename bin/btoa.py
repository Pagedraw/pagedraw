import base64
import sys
import subprocess

# useful for translating a doc downloaded from firebase into base64 so you can paste it into tests

def write_to_clipboard(output):
    process = subprocess.Popen(
        'pbcopy', env={'LANG': 'en_US.UTF-8'}, stdin=subprocess.PIPE)
    process.communicate(output.encode('utf-8'))

filename = sys.argv[-1]
file_str = open(filename, 'r').read()

write_to_clipboard(base64.b64encode(file_str))

print 'Base 64 encoding copied to your clipboard!'
