import pandas as pd
from bs4 import BeautifulSoup
import requests
from selenium import webdriver


driver = webdriver.Chrome()

#https://academic.oup.com/view-large/210299173

driver.get("https://academic.oup.com/view-large/210299174")

txt = driver.page_source
driver.quit()
soup = BeautifulSoup(txt, "html.parser")

table = soup.find_all("table")
table = table[0]

rows = table.find_all("tr")

all_data = []
for row in rows:
    headers = row.find_all("th")
    data = []
    if len(headers) > 0:
        for th in headers:
            colspan = 1
            if th.has_attr("colspan"):
                colspan = int(th["colspan"])
            data.append(th.text.strip().strip(".").strip())
            for i in range(colspan - 1):
                data.append("")
        all_data.append(data)
    else:
        d_elements = row.find_all("td")
        all_data.append(list(map(lambda x: x.text.strip(), d_elements)))
df = pd.DataFrame(all_data)

# Combine header from top 3 rows:
HEADER_ROWS = 3
header = []
for col in df.columns:
    new_col = ",".join(df.iloc[:HEADER_ROWS][col]).strip(",")
    header.append(new_col)

df.columns = header
df = df.iloc[HEADER_ROWS:]
df.to_csv("~/males.tsv", index=False, sep="\t")
