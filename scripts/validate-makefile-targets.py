import subprocess
import sys

from markdown_it import MarkdownIt

def run_make_target(target: str) -> bool:
    """Reads the content of a markdown file."""
    try:
        _ = subprocess.run(['make', '-n', target], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"Make command for target '{target}' completed successfully.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Make command for target '{target}' failed.")
        return False

def read_markdown_file(filename: str):
    """Reads the content of a markdown file."""
    with open(filename, 'r') as file:
        return file.read()

def extract_shell_code_blocks(markdown_text: str) -> None:
    """Extracts 'shell' code blocks from the given markdown text."""
    md = MarkdownIt()
    tokens = md.parse(markdown_text)

    valid_targets = True
    for token in tokens:
        if token.type == 'fence' and token.info == 'shell':
            if not check_code_block(token.content.strip()):
                valid_targets = False
    return valid_targets

def check_code_block(code: str) -> bool:
    """Checks for each line of the codeblock if it is a make command. For each found make command, a check is performed."""
    targets_valid = True
    for line in code.splitlines():
        if line.strip().startswith("make "):
            if not run_make_target(line.strip()[5:]):
                targets_valid = False
    return targets_valid

def main() -> None:
    markdown_text = read_markdown_file('README.md')
    if not extract_shell_code_blocks(markdown_text):
        sys.exit(1)

# Run the program
if __name__ == "__main__":
    main()
