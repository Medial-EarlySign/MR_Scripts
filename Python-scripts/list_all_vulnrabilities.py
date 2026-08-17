"""
Close all vulnrabilities
"""

import lxml.html
import pandas as pd
import glob
import os

MR_LIBS = os.environ["MR_LIBS"]
# url = "https://github.com/Medial-EarlySign/medpython/security/code-scanning"
data = "/tmp/data.txt"

with open(data, "r") as fr:
    txt = fr.read()

root = lxml.html.fromstring(txt)

# Extract all <a> tags where the href starts with "/Medial-EarlySign/medpython/security/"
links = root.xpath('//a[starts-with(@href, "/Medial-EarlySign/medpython/security/")]')

for link in links:
    print(link.attrib["href"])

links = list(
    filter(lambda x: len(x.text.strip()) > 0 and "aria-describedby" in x.attrib, links)
)
all_bugs = list(
    map(lambda x: x.getparent().text_content().strip().split("\n")[0], links)
)

df = pd.DataFrame(
    {
        "file": list(map(lambda x: x.split(" :")[0], all_bugs)),
        "line": list(map(lambda x: x.split(" :")[1], all_bugs)),
    }
)

df["file"] = df["file"].apply(
    lambda x: glob.glob(MR_LIBS + "/" + x.replace("...", "*"))[0]
)
df["line"] = df["line"].astype(int)

df = df.sort_values(["file", "line"], ascending=[True, False], ignore_index=True)
df["status"] = 0

fixed_files = [
    "InMemData.cpp",
    "MedPidRepository.cpp",
    "MedLightGBM.cpp",
    "TQRF.cpp",
    "micNet.cpp",
]

for f in fixed_files:
    df.loc[(df["file"].str.endswith(f)), "status"] = 1

df.to_csv("/tmp/inst.csv", index=False)
