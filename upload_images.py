import subprocess
import json
import os

images = {
    'yoga': 'assets/images/categories/yoga.png',
    'hiit': 'assets/images/categories/hiit.png',
    'strength': 'assets/images/categories/strength.png',
    'cardio': 'assets/images/categories/cardio.png',
    'pilates': 'assets/images/categories/pilates.png'
}

cloudinary_cloud_name = 'dntnzraxh'
cloudinary_preset = 'gym_uploads'

results = {}

print("Starting uploads...")
for key, path in images.items():
    if not os.path.exists(path):
        print(f"File {path} does not exist for {key}")
        continue
    
    print(f"Uploading {key}...")
    cmd = [
        'curl', '-s', '-X', 'POST', 
        '-F', f'file=@{path}', 
        '-F', f'upload_preset={cloudinary_preset}', 
        f'https://api.cloudinary.com/v1_1/{cloudinary_cloud_name}/image/upload'
    ]
    
    try:
        output = subprocess.check_output(cmd)
        data = json.loads(output)
        if 'secure_url' in data:
            results[key] = data['secure_url']
            print(f"Success {key}: {data['secure_url']}")
        else:
            print(f"Error uploading {key}: {data}")
    except Exception as e:
        print(f"Failed to upload {key}: {e}")

# Save results
with open('cloudinary_urls.json', 'w') as f:
    json.dump(results, f)

print("Finished uploads.")
