import urllib.request
import re
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
output_filename = os.path.join(script_dir, '../kubernetes/base/security/authelia/resources/letsencrypt-certs.pem')

def get_and_combine_letsencrypt_intermediates():
    """
    Scrapes Let's Encrypt's certificates page for intermediate .pem links,
    downloads them using only standard libraries, and combines their contents
    into a single fullchain.pem file.
    """
    le_cert_page = "https://letsencrypt.org/certificates/"

    try:
        print(f"Fetching certificate links from {le_cert_page}...")
        with urllib.request.urlopen(le_cert_page) as response:
            html = response.read().decode('utf-8')

        # Use regex to find all hrefs that end with ".pem"
        cert_links = re.findall(r'href="([^"]+\.pem)"', html)

        if not cert_links:
            print("No .pem links found on the page.")
            return

        with open(output_filename, 'w') as outfile:
            for link in cert_links:
                # Construct the full URL if the link is relative
                cert_url = urllib.parse.urljoin(le_cert_page, link)

                print(f"Downloading certificate from {cert_url}...")

                # Fetch certificate content
                with urllib.request.urlopen(cert_url) as cert_response:
                    cert_content = cert_response.read().decode('utf-8')
                    outfile.write(cert_content)

        print(f"Success! All intermediate certificates have been combined into {output_filename}.")

    except urllib.error.URLError as e:
        print(f"An error occurred during the request: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    get_and_combine_letsencrypt_intermediates()
