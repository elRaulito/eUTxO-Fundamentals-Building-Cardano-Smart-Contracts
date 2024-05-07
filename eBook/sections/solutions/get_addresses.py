import requests
import json

url = "https://preview.gomaestro-api.org/v1/policy/YOURPOLICYID/addresses"
api_key = "<Your-API-Key>"
headers = {
    'Accept': 'application/json',
    'api-key': api_key
}

def get_addresses(url, headers):
    addresses = []
    next_cursor = None

    while True:
        params = {'cursor': next_cursor} if next_cursor else {}
        response = requests.get(url, headers=headers, params=params)

        if response.status_code == 200:
            data = response.json()
            addresses.extend(data.get('data', []))
            next_cursor = data.get('next_cursor')

            if not next_cursor:
                break
        else:
            print("Error:", response.status_code)
            break

    return addresses

addresses = get_addresses(url, headers)

# Write the JSON response to a file
with open('addresses.json', 'w') as file:
    json.dump(addresses, file, indent=4)

print("Addresses written to addresses.json")
