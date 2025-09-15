# imports
import argparse
import re
import shutil
import os
import sys
from typing import Dict

# formerly used python's HTML parser, changed to bs4:
# from HTMLParser import HTMLParser
from bs4 import BeautifulSoup
from bs4 import NavigableString
from bs4 import Tag

# flags
rendering_html = False
indent = -1
li_break = False
li_for_ul_only = False  # see convert_li
list_nr = 0
full_path_pages: Dict[str, str] = {}  # Page alias to full path
file_name_conv = {}  # Convertion file name

# linebreaks
md_br = "\n"
md_dbr = "\n\n"
html_br = "<br/>"
html_dbr = "<br/><br/>"


def linebreak():
    if rendering_html:
        return html_br
    else:
        return md_br


# global vars
title = "none"


# convert the passed html-tag. Delegates to convert-* functions depending on tag
def convert_html_tag(tag, folder_path: str, stats_dict: Dict[str, int] | None = None):
    if tag is None:
        return ""

    # info about this tag:
    tag_info = (
        "convert_html_tag: type="
        + (str(type(tag)))
        + ", classname="
        + tag.__class__.__name__
    )
    try:
        if (not tag.__class__ == NavigableString) and (tag.name is not None):
            tag_info += ", name=" + tag.name
    except:
        pass
    # print(tag_info)

    # check type:
    # if isinstance( type(tag), type(NavigableString) ): # would return true for <p> too, checks subtypes
    # if tag.__class__.__name__ == "NavigableString" :
    #    print("string==true")
    # if tag.__class__ == NavigableString :
    #    print("string==true")

    if tag.__class__ == NavigableString:
        return tag

    if tag.name == "div":
        return convert_div(tag, folder_path, stats_dict)
    if tag.name == "p":
        return convert_p(tag, folder_path, stats_dict)
    if tag.name == "table":
        return convert_table(tag)
    if tag.name == "img":
        return convert_img(tag, folder_path)
    if tag.name == "a":
        return convert_a(tag, folder_path, stats_dict)
    if tag.name == "ul":
        return convert_ul_ol(tag, folder_path, True, stats_dict)
    if tag.name == "pre":
        return convert_pre(tag)
    if tag.name == "b":
        return convert_b(tag)
    if tag.name == "i":
        return convert_i(tag)
    if tag.name == "span":
        # span same as div -> just process children (no linebreaks)
        return convert_div(tag, folder_path, stats_dict)
    if tag.name == "h1" or tag.name == "h2" or tag.name == "h3" or tag.name == "h4":
        return convert_header(tag, folder_path, stats_dict)
    if tag.name == "ol":
        return convert_ul_ol(tag, folder_path, False, stats_dict)
    if tag.name == "strong":
        # use bold for strong
        return convert_b(tag)
    if tag.name == "u":
        return convert_u(tag, folder_path, stats_dict)
    if tag.name == "em":
        # use italic for em
        return convert_i(tag)
    if tag.name == "blockquote":
        return convert_blockquote(tag)
    if tag.name == "map":
        return convert_map(tag)
    if tag.name == "code":
        return convert_code(tag)
    if tag.name == "hr":
        return convert_hr(tag)
    if tag.name == "br":
        return convert_br(tag)

    # tag not handled!
    if stats_dict is not None:
        if tag.name not in stats_dict:
            stats_dict[tag.name] = 0
        stats_dict[tag.name] += 1
    else:
        print("Did NOT handle tag " + tag.name)
    return ""


def convert_header(tag, folder_path, stats_dict: Dict[str, int] | None = None):

    result = ""
    result += linebreak()

    if tag.name == "h1":
        result += "# "
    if tag.name == "h2":
        result += "## "
    if tag.name == "h3":
        result += "### "
    if tag.name == "h4":
        result += "#### "

    for child in tag.children:
        if child.__class__ == NavigableString:
            if child == "\n":
                continue
            result += child.string
        # there may be inner tags for anchors. Not only <img>, but e.g. also <b> (bold text) etc:
        else:
            result += convert_html_tag(child, folder_path, stats_dict).strip()

    result += linebreak()

    return result


def convert_div(tag, folder_path, stats_dict: Dict[str, int] | None = None):

    # ignore Confluence meta-data divs:
    # try-catch id-attr
    try:
        if tag.id == "footer":
            # ignore "generate by Confluence" etc
            return ""
    except:
        pass
    # try-catch class-attr
    try:
        if tag.get("class") == "page_metadata":
            # ignore "Created by <user>"
            return ""
        if tag.get("class") == "pageSection group":
            # ignore attachments footer
            return ""
    except:
        pass

    md = ""
    for child in tag.children:
        if child.__class__ == NavigableString:
            md += child.string
        else:
            md += convert_html_tag(child, folder_path, stats_dict)
    return md


def convert_p(tag, folder_path, stats_dict: Dict[str, int] | None = None):
    md = ""
    md += linebreak()

    # How to add text in <p>text</p>?
    # - tag.text does not work: returns text of ALL children
    # - tag.string does not work: fails if there are other tags, e.g. as in <p>text<br/>more text</p>
    # So, instead traverse children and check for string or tag.
    for child in tag.children:
        # print("convert_p:child:"+(str(type(child))))
        if child.__class__ == NavigableString:
            md += child.string
            # print("NavigableString: "+child.string)
        elif child.__class__ == Tag:
            if child.name == "br":
                # print("tag-br")
                md += linebreak()
            else:
                md += convert_html_tag(child, folder_path, stats_dict)
        else:
            md += convert_html_tag(child, folder_path, stats_dict)

    # linebreak at end of tag
    md += linebreak()

    return md


def convert_br(tag):
    # md = ""
    # in most cases, an additional linebreak looks worse than none (would cause
    # lots of empty lines, e.g. in lists etc). So, just skip <br> and return empty string
    # md += linebreak()
    return ""


def convert_table(tag):
    # in markdown, tables can be represented with pipes:
    # Col1 | Col2 ...
    # or by just rendering html. As complex tables (e.g. with multi-line-code) does not work
    # with pipe-rendering, just keep the html-table as-is:
    md = ""
    md += linebreak()

    # set rendering_html, so that other tag-processing works fine. E.g. <br/> will be kept as
    # <br/> instead of being converted to \n
    global rendering_html
    rendering_html = True
    # just keep the <html>-table as-is:
    md += str(tag)
    # add linebreaks
    md = md.replace("<tbody>", "<tbody>\n\n")
    md = md.replace("<tr>", "<tr>\n")
    md = md.replace("</th>", "</th>\n")
    md = md.replace("</td>", "</td>\n")
    md = md.replace("</tr>", "</tr>\n\n")
    # remove confluence-CSS
    md = md.replace(' class="confluenceTd"', "")
    md = md.replace(' class="confluenceTr"', "")
    md = md.replace(' class="confluenceTh"', "")
    md = md.replace(' class="confluenceTable"', "")
    md = md.replace(' colspan="1"', "")
    rendering_html = False

    # linebreak at end of tag
    md += linebreak()
    md += linebreak()

    return md


def convert_img(tag, folder_path: str):
    # render img as html. Why? Cause markdown has no official/working
    # image-size-support (which i do require for markdown wiki)

    src = tag.get("src")

    # Extract src link.
    # - if external (http...), then keep.
    # - if relative, then convert to be relative to <root>/attachments
    if not src.startswith("http"):
        # external would start with http(s), seems to be relative.

        # ignore Confluence images/icons:
        # "images/*", e.g. "images/icons/...", are by Confluence => ignore
        # include others (e.g. "attachments/*")
        if src.startswith("images"):
            # ignore complete <img> tag by returning empty string for whole tag:
            return ""

        # map to /attachments:
        lastSlash = src.rfind("/")
        # newsrc = "/attachments/" + src[(lastSlash + 1) :]
        newsrc = src
        # print("cp " + src + " " + newsrc)
        src = newsrc

    img = '<img src="/' + src + '"/>'
    return img


def convert_a(tag, folder_path, stats_dict: Dict[str, int] | None = None):
    page_with_id = re.compile("(.*)(_[0-9]+)")
    # return html as-is
    if rendering_html:
        return str(tag)

    # convert to markdown:
    # first split href-attr and text
    md = ""
    # default href = # to prevent exception due to None
    href = tag.get("href", "#")
    if href.endswith(".html"):
        href = href[:-5]
    if href == "index":
        href = "home"
    # Fix href when there is "_numbers" remove this
    real_href = str(href)
    # Find full path:

    href = page_with_id.sub(lambda m: m.group(1), href)
    # Check if there is conversion:
    if href in file_name_conv:
        # print(f'Converting link {href} to {file_name_conv[href]}')
        href = file_name_conv[href]
    dir_path = None
    if real_href in full_path_pages:
        dir_path = full_path_pages[real_href]
        href = os.path.join(dir_path, href)
    else:
        if (
            real_href != "home"
            and not (real_href.startswith("http://"))
            and not (real_href.startswith("https://"))
            and not (real_href.startswith("#"))
        ):
            # print(f'Not found {real_href}')
            pass
    # breakpoint()
    text = ""
    for child in tag.children:
        if child.__class__ == NavigableString:
            text += child.string
        # there may be inner tags for anchors. Not only <img>, but e.g. also <b> (bold text) etc:
        else:
            text += convert_html_tag(child, folder_path, stats_dict)

    # note: always render anchor-links inline. Even though markdown supports link-references (rendering
    # all links at end of page), github has issues/bugs with local/relative link-references. Whereas
    # inline-version of same links does work.
    return "[" + text + "](" + href + ")"

    return md


def convert_pre(tag):
    # pre-tag -> source code
    md = ""
    md += linebreak()

    # Confluence uses "brush" for a specified language, e.g. <pre class="brush: bash; gutter: ...
    # Note: in bs4, tag-attributes which are expected to be multi-valued (such as 'class'),
    # will return a list of values EVEN if there are colon-/semicolon values: i.e. 'brush: bash' will
    # be returned as two values
    lang = ""
    class_value_list = tag.get("class", None)
    if class_value_list is not None:
        for idx, val in enumerate(class_value_list):
            if val == "brush:":
                # next value after brush is language. Remove last char via :-1
                lang = (class_value_list[idx + 1])[:-1]
                break

    # add language-notification via HTML-comment as used on stackoverflow. This is ignored on
    # github anyway (just a comment):
    if lang != "":
        md += "<!-- language: lang-" + lang + " -->"
        md += linebreak()

    # use github-flavored markdown (three backticks):
    md += "```" + lang
    md += linebreak()

    for child in tag.children:
        if child.__class__ == NavigableString:
            md += child.string

    md += linebreak()
    md += "```"
    md += linebreak()
    return md


# convert lists, <ul> or <ol>
def convert_ul_ol(
    tag, folder_path: str, isUl, stats_dict: Dict[str, int] | None = None
):
    md = ""
    # insert linebreaks around <ul>, but NOT for nested <ul>. Therefore, linebreak
    # only if indent-level is -1:
    global indent
    global li_for_ul_only
    global list_nr
    # if indent == -1:
    if not li_for_ul_only:
        md += linebreak()
    # increase indention for each list level
    indent += 1
    # list_nr += 1
    list_nr = 1
    is_navigation_menu = tag.get("id") == "breadcrumbs"
    for child in tag.children:
        if child.__class__ == Tag:
            if child.name == "li":
                li_ele = convert_li(
                    child, folder_path, isUl, is_navigation_menu, stats_dict
                )
                if is_navigation_menu:
                    li_ele = li_ele.strip()
                md += li_ele
    # reset indention
    indent -= 1
    list_nr -= 1
    if indent == -1:
        md += linebreak()
    return md


def convert_li(
    tag,
    folder_path: str,
    isUl,
    is_navigation_menu: bool,
    stats_dict: Dict[str, int] | None = None,
):
    # each <li> is prefixed with a dash
    md = ""
    global indent
    global li_break
    global list_nr
    # reset li_break, see end of function
    li_break = False
    # true if current <li> exist for purpose of single <ul> only, as in "<li><ul><li>content</li></ul></li>
    global li_for_ul_only
    # reset li_for_ul_only, might be True from previous nested list-element
    li_for_ul_only = False

    # check if current <li> exist for purpose of single <ul> only, as in "<li><ul><li>content</li></ul></li>
    if (
        len(tag.contents) == 1
        and tag.contents[0].__class__ == Tag
        and tag.contents[0].name == "ul"
    ):
        li_for_ul_only = True

    # indent markup depending on level
    if not li_for_ul_only:
        for i in range(0, indent * 2):
            md += " "
        if is_navigation_menu:
            md += "/ "
        else:
            if isUl is True:
                md += "- "
            else:
                md += linebreak() + str(list_nr) + ". "
                list_nr += 1

    # traverse children: append strings, delegate tag processing
    for child in tag.children:
        if child.__class__ == NavigableString:
            # a string, just append it
            md += child.string
        elif child.__class__ == Tag:
            md += convert_html_tag(child, folder_path, stats_dict)

    # Linebreak after <li>. Skip if last chars in "md" already were li-break, as in </li></ul></li>.
    if not li_break and not li_for_ul_only:
        md += linebreak()
        li_break = True

    return md


# <b> bold tag
def convert_b(tag):
    # use ** for bold text (markdown also supports __, but ** better distincts from list dash -
    md = "**"
    for child in tag.children:
        if child.__class__ == NavigableString:
            md += child.string
    md += "**"
    return md


# <i> italic tag
def convert_i(tag):
    # use * for italic text (markdown also supports _, but * better distincts from list dash -
    md = "*"
    for child in tag.children:
        if child.__class__ == NavigableString:
            md += child.string
    md += "*"
    return md


# <u> tag
def convert_u(tag, folder_path: str, stats_dict):
    # there is no underline in markdown. Emphasize with bold text instead
    md = "**"
    for child in tag.children:
        if child.__class__ == NavigableString:
            md += child.string
        else:
            md += convert_html_tag(child, folder_path, stats_dict)
    md += "**"
    return md


# <blockquote> tag
def convert_blockquote(tag):
    # TODO
    return ""


# <map> tag
def convert_map(tag):
    # TODO
    return ""


# <code> tag
def convert_code(tag):
    md = ""
    md += linebreak()
    md += "```"
    md += linebreak()
    return md


# <hr> tag, horizontal line
def convert_hr(tag):
    # there is no hr equivalent in markdown. Ignore, just add some space
    md = ""
    md += linebreak()
    md += linebreak()
    return md


# convert the whole page / html_content. Taverses children and delegates logic per tag.
def convert_html_page(
    html_content, folder_path: str, stats_dicts: Dict[str, int] | None = None
):
    # let bs4 parse the html:
    soup = BeautifulSoup(html_content, "html.parser")
    # the markdown string returned as result:
    md = ""
    # Navigation bar
    div_header = soup.find("div", {"id": "main-header"})
    if div_header:
        for child in div_header.children:
            md += convert_html_tag(child, folder_path, stats_dicts)

    # html-page title: Confluence uses "spacename : pagename". Remove the spacename here
    global title
    title = ""
    if soup.title:
        title = soup.title.string
    position_colon = title.find(" : ")
    if position_colon >= 0:
        title = title[(position_colon + 3) :]
    # md += "# " + title + md_dbr
    md += md_dbr

    # goto <body><div id="main-content"> and ignore all that other Confluence-added-garbage

    div_main = soup.find("div", {"id": "main-content"})
    if div_main is None:
        return md
    # traverse all children of div_main and try to convert to markdown
    for child in div_main.children:
        md += convert_html_tag(child, folder_path, stats_dicts)

    return md


# Confluence sometimes has cryptic filenames, just consisting of digits. In that case,
# the parsed title is used instead of the original filename. If filename already has
# a string name, it is just returned.
def getMarkdownFilename(filename, html_content):
    if filename == "index":
        return ".", "home"
    bad_chars = re.compile(r"[/\\*]")
    soup = BeautifulSoup(html_content, "html.parser")
    title = ""
    if soup.title:
        title = soup.title.string
    position_colon = title.find(" : ")
    if position_colon >= 0:
        title = title[(position_colon + 3) :]
    # the markdown string returned as result:
    # Navigation bar
    div_menu = soup.find("ol", {"id": "breadcrumbs"})
    full_path = []
    if div_menu is None:
        print(f"WARNING {filename} has no menu")
    else:
        for child in div_menu.children:
            if child.__class__ != Tag:
                continue
            if child.name != "li":
                continue
            # Search till link:
            text_f = ""
            for child_c in child.children:
                if child_c.__class__ == Tag:
                    # print(child_c)
                    text_f = child_c.text
                    break
            full_path.append(text_f)

    folder_path = "/".join(full_path)
    full_path_pages[filename] = folder_path
    page_with_id = re.compile("(.*)(_[0-9]+)")
    filename_fixed = page_with_id.sub(lambda m: m.group(1), filename)
    if title != filename_fixed:
        if filename_fixed.replace("-", " ") == title.replace("-", " "):
            file_name_conv[filename_fixed] = str(title)
            filename_fixed = title
        if title != filename_fixed:
            if len(bad_chars.findall(title)) > 0:
                fixed_title = bad_chars.sub('_', title)
                file_name_conv[filename_fixed] = str(fixed_title)
                filename_fixed = fixed_title
                print(f"{title} = {filename_fixed} :FIXED TO: {fixed_title}")
            else:
                # print(f'Fixed {title} = {filename_fixed}')
                file_name_conv[filename_fixed] = str(title)
                filename_fixed = title

    # filename = os.path.join(folder_path, filename)
    return folder_path, filename_fixed
    if filename.isdigit():
        titleFilename = title
        titleFilename = titleFilename.replace(" ", "-")
        titleFilename = titleFilename.replace("++", "pp")
        titleFilename = titleFilename.replace("/", "")
        titleFilename = titleFilename.replace("+", "")
        titleFilename = titleFilename.replace("_", "-")
        titleFilename = titleFilename.replace("---", "-")
        titleFilename = titleFilename.replace("--", "-")

        print("Renaming:", filename, " -> ", title, " -> ", titleFilename)
        if titleFilename == "index":
            return "home"
        return titleFilename
    else:
        if filename == "index":
            return "home"
        return filename


# setup program arguments:
parser = argparse.ArgumentParser()
parser.add_argument(
    "source",
    help="source folder, i.e. path to Confluence html files to be converted to .md",
)
parser.add_argument(
    "dest",
    help="destination folder, i.e. path to folder where to write converted .md-files, e.g. /tmp/conf-md",
)
args = parser.parse_args()

# print info
print("------------------------------")
print("Converting Confluence (.html to .md) from")
print(args.source)
print("to")
print(args.dest)
print("------------------------------")


# with open(os.path.join(args.source, "ETL-Tutorial_14811356.html"), "r") as fin:
#     html_content = fin.read()
# markdown_content = convert_html_page(html_content)
# print(markdown_content)

# sys.exit(0)

# copy whole source tree to destination, i.e. the .html files.
# This makes it easier to handle path+folder and new .md files.
# Plus, if conversion fails for some files, one can inspect remaining html files.
shutil.copytree(args.source, args.dest, dirs_exist_ok=True)

# First pass to generate full_path_pages
html_path_to_data = {}
for root, dirs, files in os.walk(args.dest):
    for file in files:
        filename, extension = os.path.splitext(file)
        if not extension == ".html":
            continue
        html_file_path = os.path.join(root, file)
        with open(html_file_path, "r") as fin:
            html_content = fin.read()
        folder_path, file_res_name = getMarkdownFilename(filename, html_content)
        html_path_to_data[html_file_path] = [folder_path, file_res_name]

# iterate all files. Read in html, write out md
stats_dicts = {}
for root, dirs, files in os.walk(args.dest):
    for file in files:
        filename, extension = os.path.splitext(file)
        # print file, filename, extension
        # skip non-html files:
        if not extension == ".html":
            continue

        # read html
        html_file_path = os.path.join(root, file)
        with open(html_file_path, "r") as fin:
            html_content = fin.read()

        # convert html to markdown
        folder_path, file_res_name = html_path_to_data[html_file_path]
        if (
            file_res_name == ""
            or folder_path.startswith("attachments")
            or (filename in full_path_pages and full_path_pages[filename] == "")
        ):
            os.remove(html_file_path)
            # print(f'SKIP {folder_path} - empty file - {file_res_name} - {filename}')
            continue

        markdown_content = convert_html_page(html_content, folder_path, stats_dicts)
        # write markdown to .md file

        markdown_filename = "%s.md" % file_res_name
        folder_path = os.path.join(root, folder_path)
        # print(f'create dir {folder_path}')
        os.makedirs(folder_path, exist_ok=True)
        markdown_file_path = os.path.join(folder_path, markdown_filename)
        with open(markdown_file_path, "w") as fout:
            fout.write(markdown_content)

        # remove copied .html file
        os.remove(html_file_path)

for nm, nm_cnt in sorted(stats_dicts.items(), key=lambda x: -x[1]):
    print(f"Missing tag {nm}, count {nm_cnt}")
