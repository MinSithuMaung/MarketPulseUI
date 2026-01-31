# watsonx Orchestrate Embedded Chat UI (static)

This folder contains a **single-page UI** that embeds your watsonx Orchestrate agent using the `wxoLoader.js` snippet.

## Run locally

From this folder:

```bash
python -m http.server 8080
```

Then open the URL printed in the console

## Deploy

You can deploy this as a static site (Cloudflare Pages / Vercel / Netlify / S3, etc.).  
Just keep the page in **HTML strict mode** (`<!DOCTYPE html>`) and ensure the `#root` element exists.
