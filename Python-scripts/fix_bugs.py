import re
import traceback
import urllib.request
import json
import os
import pandas as pd
import re

# --- Configuration ---
BUG_REPORT_FILE = "/tmp/inst.csv"
# Default for LM Studio is 1234. For Ollama's OpenAI compatibility, use 11434.
LOCAL_LLM_URL = "http://localhost:8000/v1/chat/completions"
MODEL_NAME = "Qwen-2.5-Coder-14B"  # Change to your exact model name in Ollama/LM Studio


def call_qwen(prompt: str, code_context: str, exact_line: str):
    """Calls the local Qwen model via an OpenAI-compatible API."""
    data = {
        "model": MODEL_NAME,
        "messages": [
            {
                "role": "system",
                "content": "You are an expert C++ developer. You fix code exactly as requested. Output ONLY the raw fixed C++ code block. Do not include markdown formatting like ```cpp, and do not provide any explanations.",
            },
            {
                "role": "user",
                "content": f"{prompt}\n\nHere is the code context:\n{code_context}\n\nThe specific line need to be fixed is:\n{exact_line}",
            },
        ],
        "temperature": 0.1,  # Keep it low for predictable code edits
    }

    req = urllib.request.Request(
        LOCAL_LLM_URL,
        data=json.dumps(data).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode("utf-8"))
            return result["choices"][0]["message"]["content"].strip()
    except Exception as e:
        print(f"Error calling LLM: {e}")
        return None


def process_bug(file_path: str, line_str: int, before: int = 5, after: int = 5) -> bool:
    file_path = file_path.strip()
    target_line_idx = line_str - 1  # Convert to 0-indexed

    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return False

    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Extract 3 lines before and 3 lines after
    start_idx = max(0, target_line_idx - before)
    end_idx = min(len(lines), target_line_idx + after)

    context_lines = lines[start_idx:end_idx]
    context_str = "".join(context_lines)

    print(f"\nProcessing {file_path}:{line_str}...")
    whitespace_prefix = re.compile(r"^\s+")

    prompt = (
        "The following C++ code has a 'Multiplication result converted to larger type' warning "
        "on the middle line. Please fix it by wrapping the multiplication operands in "
        "`static_cast<size_t>(...)` or `static_cast<double>(...)` before they are multiplied. "
        "Return ONLY the exact same line of code with only the necessary fix. Pay attention, you might need to use the static_cast more than once."
    )

    fixed_context = call_qwen(prompt, context_str, lines[target_line_idx])

    if not fixed_context:
        print("Skipping due to LLM error.")
        return False

    # Clean up any potential markdown bleeding from the LLM

    if fixed_context.find("```cpp") >= 0:
        fixed_context = fixed_context[fixed_context.find("```cpp") :]
        fixed_context = fixed_context.replace("```cpp", "")
        if fixed_context.find("```") < 0:
            print(f"Skipping Can't find code:\n{fixed_context}")
            return False
        fixed_context = fixed_context[: fixed_context.find("```")]
        fixed_context = fixed_context.replace("```", "")

    # Split the LLM response back into lines to verify it didn't mangle the surrounding code
    fixed_lines: list[str] = fixed_context.strip().splitlines(keepends=True)
    lines_context = context_str.strip().splitlines(keepends=True)

    if len(fixed_lines)>1:

        if fixed_lines[0].strip() != lines_context[0].strip():
            print("Error - seems like replacing code. start error")
            print("\n############\nOriginal Lines:")
            print(lines_context)
            print("\n############\nFixed Lines:")
            print(fixed_lines)
            return False

        fixed_lines[0] = context_str.splitlines(keepends=True)[
            0
        ]  # if there are white spaces

        if fixed_lines[-1].strip() != lines_context[-1].strip():
            print("Error - seems like replacing code. end error")
            print("\n############\nOriginal Lines:")
            print(lines_context)
            print("\n############\nFixed Lines:")
            print(fixed_lines)
            return False

        # if len(fixed_lines) < end_idx-start_idx:
        fixed_lines.append("\n")

        if len(fixed_lines) > 0:
            lines[start_idx:end_idx] = fixed_lines
    
            # Write the fixed file back
            with open(file_path, "w", encoding="utf-8") as f:
                f.writelines(lines)
            print(f"Successfully patched {file_path}")
        else:
            print(f"Failed to parse LLM output for {file_path}")
            return False
    else:
        print("Using the one line")
        whitespace_p = ""
        if whitespace_prefix.search(lines[target_line_idx]):
            whitespace_p = whitespace_prefix.findall(lines[target_line_idx])[0]
        lines[target_line_idx] = whitespace_p + fixed_lines[0] + "\n"
        with open(file_path, "w", encoding="utf-8") as f:
            f.writelines(lines)
        print(f"Successfully patched {file_path}")

    # Replace the original lines with the fixed lines
    return True


def process_bugs():
    # Read the full bug report
    df = pd.read_csv(BUG_REPORT_FILE)
    if "status" in df.columns:
        df = df[(df["status"].isna()) | (df["status"] < 1)].reset_index(drop=True)

    # skip BART for now
    df = df[~df["file"].str.endswith("BART.cpp")].reset_index(drop=True)
    print(f"Found {len(df)} bugs to process.")
    df["status"] = 0

    # range(10)
    for i in range(3):
        file_path = df["file"].iloc[i].strip()
        target_line_idx = int(df["line"].iloc[i])
        try:
            if process_bug(file_path, target_line_idx):
                df.loc[df.index == i, "status"] = 1
        except:
            traceback.print_exc()

    df.to_csv("/tmp/inst2.csv", index=False)


if __name__ == "__main__":
    process_bugs()
