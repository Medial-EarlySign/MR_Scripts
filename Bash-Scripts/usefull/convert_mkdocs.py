#!/usr/bin/env python
import os
import shutil
from typing import Callable, Dict, List, Any
import re
import sys

# BASE_FLD = "/var/wiki.new/docs"
BASE_FLD = "/home/alon-internal/MR_ROOT/Wiki"
if len(sys.argv) > 1:
    BASE_FLD = sys.argv[1]

def call_rec(
    pt: str, args: Dict[str, Any], call_func: Callable[[str, Dict[str, Any]], None]
):
    skip_list_root = [
        "attachments",
        ".git",
        ".gitlab",
        ".gitlab-ci.yml",
        "images",
        "styles",
        "index.md",
    ]

    for dirn in os.listdir(pt):
        if dirn in skip_list_root:
            continue
        call_func(os.path.join(pt, dirn), args)


def rec_handle_call(
    full_pt: str,
    func: Callable[[str, Dict[str, Any] | None], None],
    args: Dict[str, Any] | None,
):
    all_files = os.listdir(full_pt)
    for f in all_files:
        ff = os.path.join(full_pt, f)
        if os.path.isfile(ff) and ff.endswith(".md"):
            func(ff, args)
        if os.path.isdir(ff):
            rec_handle_call(ff, func, args)


def full_wrapper(
    pt: str,
    func: Callable[[str, Dict[str, Any] | None], None],
    args: Dict[str, Any] | None = None,
):
    call_rec(pt, args, lambda file_path, args_: rec_handle_call(file_path, func, args_))


def handle_dir(full_pt: str, args: Dict[str, Any]) -> None:
    all_files = os.listdir(full_pt)
    for f in all_files:
        ff = os.path.join(full_pt, f)
        if os.path.isfile(ff) and ff.endswith(".md"):
            dname = ff[:-3]
            if os.path.exists(dname) and os.path.isdir(dname):
                if args["dry"]:
                    print(f"Will move {ff} to {os.path.join(dname, 'index.md')}")
                else:
                    shutil.move(ff, os.path.join(dname, "index.md"))
        if os.path.isdir(ff):
            handle_dir(ff, args)


def clean_all(pt: str, dry: bool = True):
    call_rec(pt, {"dry": dry}, handle_dir)


def clean_txt(lines: List[str]) -> str:
    state = 0
    found_skip = None
    for ii, ln in enumerate(lines):
        if ln.strip() == "" and state == 0:
            continue
        if ln.startswith("/") and state == 0:
            state = 1
        if ln.strip() == "" and state == 1:
            found_skip = ii
            break
    if found_skip:
        lines = lines[found_skip:]
    s = "\n".join(lines)
    return s


def clean_header(lines: List[str]) -> str:
    state = 0
    found_skip = None
    header_line = None
    for ii, ln in enumerate(lines):
        if ln.strip() == "" and state == 0:
            continue
        else:
            state = 1
        if state > 0:
            header_line = ln
            pos = ln.find("# Wikimedial : ")
            if pos >= 0:
                header_line = "# " + ln[pos + len("# Wikimedial : ") :]
            found_skip = ii
            break
    if found_skip:
        final_lines = [header_line] + lines[found_skip + 1 :]
        s = "\n".join(final_lines)
    else:
        s = ""
        # print('Empty file!!!')
    s = re.compile("\n{2,}").sub("\n\n", s)
    return s


def handle_header(full_pt: str, args: Dict[str, Any] | None):
    with open(full_pt, "r") as fr:
        content_lines = fr.readlines()
    clean_content = clean_txt(content_lines)
    with open(full_pt, "w") as fw:
        fw.write(clean_content)


def remove_header(pt: str):
    full_wrapper(pt, handle_header)


def handle_header2(full_pt: str, args: Dict[str, Any] | None):
    with open(full_pt, "r") as fr:
        content_lines = fr.readlines()

    clean_content = clean_header(content_lines)
    if clean_header == "":
        print(f"Empty {full_pt}")

    with open(full_pt, "w") as fw:
        fw.write(clean_content)


def fix_link(base_path: str, file_path: str, link: str, verbose: bool):
    # Get relative path:
    relative_file_path = file_path[len(base_path) + 1 :]  # /Search for all path?
    current_dir_name = os.path.basename(file_path)
    if current_dir_name == "index.md":
        current_dir_name = os.path.basename(os.path.dirname(file_path))
    # Remove the Wikimedial/.*/$current_dir_name
    new_link = link
    repl_regex = re.compile(rf"Wikimedial/.*/{current_dir_name}/")
    new_link = repl_regex.sub("", new_link)
    if new_link.startswith("Wikimedial/Wikimedial/"):
        new_link = new_link[len("Wikimedial/Wikimedial/") :]
    if verbose:
        if new_link != link:
            print(f"{file_path} - {current_dir_name} - Replace {link} => {new_link}")
        else:
            print(f"{file_path} - Kept Link {link}")
    new_link = new_link.replace(" ", "%20")
    return new_link


def fix_link2(base_path: str, file_path: str, link: str, verbose: bool):
    # Get relative path:

    relative_file_path = file_path[len(base_path) + 1 :]  # /Search for all path?
    current_dir_name = os.path.dirname(relative_file_path)
    # if current_dir_name == "index.md":
    #     current_dir_name = os.path.dirname(os.path.dirname(file_path))
    # elif file_path.endswith(".md"):
    #     file_path = file_path[:-3]
    #     current_dir_name = os.path.dirname(file_path)
    if relative_file_path.find(" ") < 0:  # only handle paths with spaces in file path
        return link
    # if (file_path == "/home/alon-internal/MR_ROOT/Wiki/Infrastructure Home Page/MedProcessTools Library/MedLabels.md"):
    #    breakpoint()
    link = link.replace("%20", " ")
    new_link = link
    repl_regex = re.compile(rf"{current_dir_name}/")
    new_link = repl_regex.sub("", new_link)
    if verbose:
        if new_link != link:
            print(f"{file_path} - {current_dir_name} - Replace {link} => {new_link}")
    new_link = new_link.replace(" ", "%20")
    return new_link


def fix_link3(base_path: str, file_path: str, link: str, verbose: bool):
    # Get relative path:

    relative_file_path = file_path[len(base_path) + 1 :]  # /Search for all path?
    current_dir_name = os.path.dirname(relative_file_path)
    # if current_dir_name == "index.md":
    #     current_dir_name = os.path.dirname(os.path.dirname(file_path))
    # elif file_path.endswith(".md"):
    #     file_path = file_path[:-3]
    #     current_dir_name = os.path.dirname(file_path)
    # if (file_path == "/home/alon-internal/MR_ROOT/Wiki/Infrastructure Home Page/MedProcessTools Library/MedLabels.md"):
    #    breakpoint()
    link = link.replace("%20", " ")
    new_link = link
    for BASE_PATH in [
        "Medial Tools",
        "Environments",
        "Archive",
        "Infrastructure Home Page",
        "Models",
        "Python",
        "Repositories",
        "Research",
        "New employee landing page",
    ]:
        pos = link.find(f"{BASE_PATH}/")
        if pos == 0 or pos > 1:
            new_link = f"/{BASE_PATH}/" + link[pos + len(f"{BASE_PATH}/") :]
        if verbose:
            if new_link != link:
                print(
                    f"{file_path} - {current_dir_name} - Replace {link} => {new_link}"
                )
    new_link = new_link.replace(" ", "%20")
    return new_link


def fix_link4(base_path: str, file_path: str, link: str, verbose: bool):
    # when I'm inside .md fild paht is like folder and i reference a page next ot me:
    if link.startswith("http") or link.startswith("/") or link.startswith(".."):
        return link
    relative_file_path = file_path[len(base_path) + 1 :]  # /Search for all path?
    current_dir_name = os.path.basename(relative_file_path)
    like_folder = False
    if current_dir_name == "index.md":
        current_dir_name = os.path.basename(os.path.dirname(file_path))
        relative_file_path = os.path.dirname(relative_file_path)
    elif file_path.endswith(".md"):
        file_path = file_path[:-3]
        like_folder = True
        current_dir_name = os.path.basename(file_path)
        relative_file_path = relative_file_path[:-3]
    # if current_dir_name == "Test_02 - test samples":
    #    breakpoint()
    link = link.replace("%20", " ")
    new_link = link
    pos = new_link.find(current_dir_name + "/")
    if pos == 0 or pos > 0 and new_link.startswith("/"):
        new_link = new_link[pos + len(current_dir_name) + 1 :]
    pp = os.path.dirname(relative_file_path) + "/"
    if pp != "/" and new_link.find(pp) >= 0:
        new_link = new_link[new_link.find(pp) + len(pp) :]
    if like_folder and new_link.find("/") < 0:
        new_link = "../" + new_link
    if verbose:
        if new_link != link:
            print(f"{file_path} - {pp} - Replace '{link}' => '{new_link}'")
    new_link = new_link.replace(" ", "%20")
    return new_link


def fix_links(
    base_path: str,
    file_path: str,
    content: str,
    verbose: bool,
    func: Callable[[str, str, str, bool], str],
) -> str:
    # Find links and fix them:
    reg_links = re.compile(r"(?P<link_desc>\[[^\]]+\]\()(?P<link_path>[^\)]+)\)")
    new_text = ""
    last_pos = 0
    for mat in reg_links.finditer(content):
        start, end = mat.span()
        current_link = mat.group("link_path")
        # Construct new_link:
        new_link = func(base_path, file_path, current_link, verbose)

        new_link_replacment = mat.group("link_desc") + new_link + ")"
        # Replace:
        new_text += content[last_pos:start] + new_link_replacment
        last_pos = end
    new_text += content[last_pos:]

    # content = reg_links.sub(rf'\g<link_desc>{new_link})',content)
    # breakpoint()
    return new_text


def fix_link_wrapper(full_pt: str, args: Dict[str, Any]):
    func: Callable[[str, str, str, bool], str] = args["func"]
    all_files = os.listdir(full_pt)
    for f in all_files:
        ff = os.path.join(full_pt, f)
        if os.path.isfile(ff) and ff.endswith(".md"):
            with open(ff, "r") as fr:
                txt = fr.read()
            new_txt = fix_links(args["base_path"], ff, txt, args["dry"], func)
            if not (args["dry"]):
                with open(ff, "w") as fw:
                    fw.write(new_txt)

        if os.path.isdir(ff):
            fix_link_wrapper(ff, args)


def fix_all_links(
    base_path: str, func: Callable[[str, str, str, bool], str], dry: bool = True
):
    call_rec(
        base_path,
        {"dry": dry, "base_path": base_path, "func": func},
        fix_link_wrapper,
    )


def merge_path_s(base_path: str, pt: str, all_paths: Dict[str, Any]):
    all_files = os.listdir(pt)
    for f in all_files:
        ff = os.path.join(pt, f)
        if os.path.isfile(ff) and ff.endswith(".md"):
            relative_path = ff[len(base_path) + 1 :]
            tokens = relative_path.split(os.path.sep)
            # Create hir:
            current_h = all_paths
            for p in tokens[:-1]:
                if p not in current_h:
                    current_h[p] = {}
                current_h = current_h[p]
            current_h[tokens[-1]] = {}
        if os.path.isdir(ff):
            merge_path_s(base_path, ff, all_paths)


def move_contents_and_merge(src: str, dst: str):
    if not os.path.exists(dst):
        os.makedirs(dst)

    all_childs = os.listdir(src)
    for item in all_childs:
        s = os.path.join(src, item)
        d = os.path.join(dst, item)
        if os.path.isdir(s):
            shutil.copytree(s, dst, dirs_exist_ok=True)
            shutil.rmtree(s)
        else:
            shutil.copy2(s, d)
            os.remove(s)
    os.rmdir(src)


def merge_paths_actual(pt: str, base_path: List[str], path1: str, path2: str):
    # Merge to "path1" to "path2"
    base_path_str = os.path.join(pt, os.path.sep.join(base_path))
    if not(os.path.exists(os.path.join(base_path_str, path1))):
        print(f'Already did {base_path}: Merging: {path1} {path2}')
        return
    print(f"Found under {base_path}: Merging: {path1} {path2}")
    move_contents_and_merge(
        os.path.join(base_path_str, path1), os.path.join(base_path_str, path2)
    )
    # breakpoint()


def fix_paths(pt: str, all_path: Dict[str, Any], current_leaf_path: List[str]) -> None:
    # Test full path for spaces:
    c = all_path
    current_hir = []
    for node in current_leaf_path:
        # Before moving next, please check if there are similar paths:
        if node.find(" ") or node.find("-"):
            all_nodes_in_level = list(c.keys())
            node_all_spaces = node.replace("-", " ")
            node_all_m = node.replace(" ", "-")
            if node_all_m in all_nodes_in_level and node != node_all_m:
                merge_paths_actual(pt, current_hir, node_all_m, node)
                # Need to merge them!
            if node_all_spaces in all_nodes_in_level and node != node_all_spaces:
                merge_paths_actual(pt, current_hir, node, node_all_spaces)
                # Need to merge them!
        c = c[node]
        current_hir.append(node)


def traverse_to_leaf(
    pt: str,
    all_path: Dict[str, Any],
    current_path: List[str],
    logic: Callable[[str, Dict[str, Any], List[str]], None],
):
    if len(current_path) > 0 and current_path[-1].endswith(".md"):
        logic(pt, all_path, current_path)
        return True  # This is leaf - stop, do logic here
    # Not leaf - traverse:
    cc = all_path
    for t in current_path:
        cc = cc[t]
    for t in cc.keys():
        traverse_to_leaf(pt, all_path, current_path + [t], logic)


def merge_path_spaces(pt: str):
    skip_list_root = [
        "attachments",
        ".git",
        ".gitlab",
        ".gitlab-ci.yml",
        "images",
        "styles",
        "index.md",
    ]
    if (pt.endswith(os.path.sep)):
        pt = pt[:-1]

    all_paths = {}
    for dirn in os.listdir(pt):
        if dirn in skip_list_root:
            continue
        merge_path_s(pt, os.path.join(pt, dirn), all_paths)
    # Now let's merge hir based on all_paths - BFS search:
    traverse_to_leaf(pt, all_paths, [], fix_paths)


# clean_all(BASE_FLD, False)
# remove_header(BASE_FLD)
# fix_all_links(BASE_FLD, fix_link4, False)
# full_wrapper(BASE_FLD, handle_header2)
merge_path_spaces(BASE_FLD)
