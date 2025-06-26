#!/usr/bin/python3
import re
import os
import urllib.request
import argparse
import json
import sys
import random
from pathlib import Path

# ANSI escape codes for colors and styles
# \x1b[  - Introduces a control sequence
# [0m   - Reset / Normal
# [31m  - Red foreground
# [32m  - Green foreground
# [39m  - Default foreground color
# [91m  - Bright Red
# [92m  - Bright Green
# [97m  - Bright White
# [2K   - Erase line

ERASE_LINE = "\x1b[2K"
COLOR_RESET = "\x1b[0m"
COLOR_RED = "\x1b[31m"
COLOR_BRIGHT_GREEN = "\x1b[92m"
COLOR_BRIGHT_WHITE = "\x1b[97m"

COLOR_NAME_TO_CODE = {
    "default": "",
    "red": COLOR_RED,
    "green": COLOR_BRIGHT_GREEN,
    "white": COLOR_BRIGHT_WHITE
}


def print_text(text, color="default", in_place=False, **kwargs):  # type: (str, str, bool, any) -> None
    """
    Print text to console, a wrapper to built-in print, with color support.

    :param text: The text string to print.
    :param color: The desired color for the text. Can be "red", "green", "white", or "default".
                  If "default", no specific color code is applied, but the text is still reset.
    :param in_place: If True, erases the current line and prints the text in its place,
                     useful for progress updates.
    :param kwargs: Other keyword arguments to pass directly to the built-in print function.
    """
    if in_place:
        print("\r" + ERASE_LINE, end="")
    print(COLOR_NAME_TO_CODE.get(color, "") + text + COLOR_RESET, **kwargs)


def get_proxy(proxies=None):
    """
    Configures and returns a urllib proxy handler.

    :param proxies: A list of proxy strings (e.g., 'ip:port'). If None, no proxy is used.
    :return: A urllib.request.ProxyHandler instance.
    """
    proxy = urllib.request.ProxyHandler({})  # Default no-proxy handler
    if proxies is not None:
        # Select a random proxy from the list
        option = 'http://' + random.choice(proxies)
        print_text(f'\nTrying Proxy: {option}', "green", in_place=True)
        proxy = urllib.request.ProxyHandler({'http': option})
    return proxy


def create_url(url):
    """
    Transforms a GitHub repository URL into a GitHub API URL for content retrieval.
    Handles both 'tree' (directory) and 'blob' (file) paths.

    :param url: The original GitHub URL.
    :return: A tuple containing (api_url, download_directory_name).
    :raises SystemExit: If the URL is a full repository (suggests 'git clone') or
                        if the repository structure cannot be parsed.
    """
    # Regex to match a base GitHub repository URL
    repo_only_url = re.compile(r"https:\/\/github\.com\/[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38}\/[a-zA-Z0-9]+")
    # Regex to extract the branch name from 'tree' or 'blob' paths
    re_branch = re.compile("/(tree|blob)/(.+?)/")

    branch = re_branch.search(url)
    if re.match(repo_only_url, url) and branch is None:
        # If it's a full repo URL without a tree/blob path, advise git clone
        print_text("✘ The given url is a complete repository. Use 'git clone' to download the repository",
                   "red", in_place=True)
        sys.exit()

    if branch:
        # Extract the part of the URL after the branch (the path to the directory/file)
        download_dirs = url[branch.end():]
        # Construct the GitHub API URL for contents
        api_url = (url[:branch.start()].replace("github.com", "api.github.com/repos", 1) +
                   "/contents/" + download_dirs + "?ref=" + branch.group(2))
        # Return the API URL and the last segment of the path (the directory/file name)
        return api_url, download_dirs.split('/')[-1]
    else:
        # If no branch is found, the URL is likely invalid
        print_text("✘ Couldn't find the repo, Pls check the URL!!!", "red", in_place=True)
        sys.exit()


def download(repo_url, proxies=None, output_dir="./", flatten=False, exts=None, file_count=0):
    """
    Downloads files and directories from a given GitHub repository URL.

    :param repo_url: The GitHub URL of the directory or file to download.
    :param proxies: A list of proxy strings to use for requests.
    :param output_dir: The base directory where content will be downloaded.
    :param flatten: If True, all files are downloaded directly into output_dir,
                    ignoring the original directory structure.
    :param exts: A list of file extensions (e.g., ['.py', '.txt']) to filter downloads.
                  If None, all files are downloaded.
    :param file_count: Internal counter for downloaded files (used recursively).
    :return: The total count of downloaded files.
    :raises SystemExit: On critical errors like KeyboardInterrupt, HTTP errors, or other unexpected issues.
    """

    # Ensure output_dir is a Path object for cross-platform compatibility
    output_dir = Path(output_dir)

    # Get the proxy handler
    proxy = get_proxy(proxies)

    # Generate the API URL and the name of the directory/file to download
    api_url, download_dir = create_url(repo_url)

    # Determine the actual output directory based on 'flatten' flag
    if not flatten:
        dir_out = Path(output_dir) / download_dir
    else:
        dir_out = Path(output_dir)

    # Attempt to fetch the API response (JSON data about contents)
    try:
        # Build an opener with proxy and user-agent for urllib requests
        opener = urllib.request.build_opener(proxy)
        opener.addheaders = [('User-agent',
                              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36')]
        urllib.request.install_opener(opener)
        response = urllib.request.urlretrieve(api_url)
    except KeyboardInterrupt:
        print_text("✘ Got interrupted", "red", in_place=True)
        sys.exit()
    except urllib.error.HTTPError as e:
        if e.code == 403:  # API Rate limit exceeded
            print_text("API Rate limit exceeded!!! Trying again with proxy if available.", "red", in_place=True)
            # Recursively call download, hoping a new proxy helps or retrying
            # Note: This recursive call does not accumulate file_count. The current file_count will be returned.
            return download(repo_url, proxies, dir_out, flatten, exts=exts, file_count=file_count)
        else:
            print_text(f"✘ HTTP Error: {e.code} - {e.reason}", "red", in_place=True)
        sys.exit()
    except Exception as e:  # Catch any other unexpected errors during API call
        print_text(f"✘ An unexpected error occurred during API request: {e}", "red", in_place=True)
        sys.exit()

    # Create the output directory if it doesn't exist
    try:
        os.makedirs(dir_out, exist_ok=True)  # exist_ok=True prevents error if dir already exists
    except Exception as e:
        print_text(f"✘ Failed to create directory '{dir_out}': {e}", "red", in_place=True)
        sys.exit()

    # Read and parse the JSON response
    with open(response[0], "r") as f:
        data = json.load(f)

        # If the response is for a single file (not a directory listing)
        if isinstance(data, dict) and data["type"] == "file":
            try:
                # Set up opener for actual file download
                opener = urllib.request.build_opener(proxy)
                opener.addheaders = [('User-agent',
                                      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.47 Safari/537.36')]
                urllib.request.install_opener(opener)

                # Check if file extension matches the filter, or if no filter is specified
                if exts is None or (exts is not None and os.path.splitext(data['download_url'])[1] in exts):
                    urllib.request.urlretrieve(data["download_url"], Path(dir_out) / data['name'])
                    file_count += 1
                    # Print "Downloaded: " in green, and filename in white
                    print_text("Downloaded: " + COLOR_BRIGHT_WHITE + "{}".format(data["name"]), "green", in_place=True)
                return file_count
            except KeyboardInterrupt:
                print_text("✘ Got interrupted", 'red', in_place=False)
                sys.exit()
            except urllib.error.HTTPError as e:
                if e.code == 403:
                    print_text("API Rate limit exceeded!!! Trying again with proxy if available.", "red", in_place=True)
                    # Note: This recursive call does not accumulate file_count. The current file_count will be returned.
                    return download(data["html_url"], proxies, dir_out, flatten, exts=exts, file_count=file_count)
                else:
                    print_text(f"✘ HTTP Error during file download: {e.code} - {e.reason}", "red", in_place=True)
                sys.exit()
            except Exception as e:
                print_text(f"✘ An unexpected error occurred during single file download: {e}", "red", in_place=True)
                sys.exit()

        # If the response is a directory listing (list of files/subdirectories)
        for file in data:
            file_url = file["download_url"]
            file_name = file["name"]

            if file_url is not None:  # It's a file
                try:
                    path = Path(dir_out) / file_name
                    opener = urllib.request.build_opener(proxy)
                    opener.addheaders = [('User-agent',
                                          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36')]
                    urllib.request.install_opener(opener)

                    # Check extension filter before downloading
                    if exts is None or (exts is not None and os.path.splitext(file_url)[1] in exts):
                        urllib.request.urlretrieve(file_url, path)
                        file_count += 1
                        # Print "Downloaded: " in green, and filename in white
                        print_text("Downloaded: " + COLOR_BRIGHT_WHITE + "{}".format(file_name), "green",
                                   in_place=False,
                                   end="\n", flush=True)

                except KeyboardInterrupt:
                    print_text("✘ Got interrupted", 'red', in_place=False)
                    sys.exit()
                except urllib.error.HTTPError as e:
                    if e.code == 403:
                        print_text("API Rate limit exceeded!!! Trying again with proxy if available.", "red",
                                   in_place=True)
                        # Note: This recursive call does not accumulate file_count. The current file_count will be returned.
                        return download(file["html_url"], proxies, dir_out, flatten, exts=exts, file_count=file_count)
                    else:
                        print_text(f"✘ HTTP Error during file download: {e.code} - {e.reason}", "red", in_place=True)
                    sys.exit()
                except Exception as e:
                    print_text(f"✘ An unexpected error occurred during directory item download: {e}", "red",
                               in_place=True)
                    sys.exit()
            else:  # It's a directory
                # Recursively call download for the subdirectory and add its returned file count
                # to the current file_count. Pass file_count=0 to the recursive call so it starts
                # its own count for its subtree.
                file_count += download(file["html_url"], proxies, dir_out, flatten, exts=exts, file_count=0)

    return file_count


def main():
    """
    Main function to parse command-line arguments and initiate the download process.
    """
    parser = argparse.ArgumentParser(description="Download directories/folders from GitHub")
    parser.add_argument('urls', nargs="+",
                        help="List of Github directories to download.")
    parser.add_argument('--output_dir', "-d", dest="output_dir", default="./",
                        help="All directories will be downloaded to the specified directory.")

    parser.add_argument('--flatten', '-f', action="store_true",
                        help='Flatten directory structures. Do not create extra directory and download found files to'
                             ' output directory. (defaults to current directory if not specified)')

    parser.add_argument('--proxy', '-p', dest='proxies', default=None,
                        help="Path to a text file containing HTTP proxies (one per line).")
    parser.add_argument('--exts', '-e', nargs="+", dest='exts', default=None,
                        help="List of file extensions (e.g., '.py', '.txt') which you want to download.")

    args = parser.parse_args()

    flatten = args.flatten
    exts = args.exts

    proxies = args.proxies
    if proxies is not None:
        try:
            with open(proxies, 'r') as f:
                proxies = f.read().splitlines()
        except FileNotFoundError:
            print_text("✘ No proxy text file found at the specified path!", "red", in_place=True)
            proxies = None  # Reset proxies to None if file not found
        except Exception as e:
            print_text(f"✘ Error reading proxy file: {e}", "red", in_place=True)
            proxies = None

    # Iterate through each URL provided and initiate download
    for url in args.urls:
        total_files = download(url, proxies, args.output_dir, flatten, exts)
        if total_files > 0:
            print_text(f"✔ Download Complete. Total files downloaded: {total_files}", "green", in_place=True)
        else:
            print_text("✘ No files were found or downloaded from this URL!!!", "red", in_place=True)


if __name__ == "__main__":
    main()
