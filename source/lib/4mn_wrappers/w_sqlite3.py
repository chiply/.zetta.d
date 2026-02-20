# sourcefile: ${sourcefile}
import sqlite3
import pandas as pd

# create connection, note all queries in code execute over this connection
CON = sqlite3.connect("${sqlite3dbpath}")

code = """\n${code}\n"""


def execute_query(query):
    print("${sqlite3dbpath}")

    cur = CON.cursor()
    cur.execute(query)
    data = cur.fetchall()
    if cur.description and isinstance(cur.description, tuple):
        columns = [f[0] for f in cur.description]
        CON.commit()
        cur.close()
        return pd.DataFrame(data=data, columns=columns)

    elif not cur.description:
        CON.commit()
        cur.close()
        return


for query in [query for query in code.split(";") if query.strip() != ""]:
    result = execute_query(query)
    print(query, "\n")
    print(result, "\n")

CON.close()
