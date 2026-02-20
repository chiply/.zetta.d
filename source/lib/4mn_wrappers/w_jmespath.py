import jmespath
import json
import pprint
import sys
import os
pp = pprint.PrettyPrinter(indent=4)

jmespath_expression = """\n${code}\n"""

with open(os.path.expanduser('${json_file}'), 'r') as f:
    json_document = json.loads(f.read())

pp.pprint(jmespath.search(jmespath_expression, json_document))

