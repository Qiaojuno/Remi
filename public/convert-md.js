const fs = require('fs');
const { marked } = require('marked');

const template = (title, content) => `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title} - Halloo</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #000;
            border-bottom: 2px solid #B9E3FF;
            padding-bottom: 10px;
        }
        h2 {
            color: #000;
            margin-top: 30px;
        }
        h3 {
            color: #555;
        }
        .last-updated {
            color: #7A7A7A;
            font-style: italic;
        }
        ul {
            margin: 10px 0;
        }
        li {
            margin: 5px 0;
        }
        strong {
            color: #000;
        }
        hr {
            border: 0;
            border-top: 1px solid #ddd;
            margin: 30px 0;
        }
        a {
            color: #0066cc;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .back-link {
            display: inline-block;
            margin-bottom: 20px;
            padding: 10px 15px;
            background: #B9E3FF;
            color: #000;
            border-radius: 8px;
            text-decoration: none;
        }
        .back-link:hover {
            background: #a5d8ff;
        }
    </style>
</head>
<body>
    <a href="index.html" class="back-link">← Back to Legal Documents</a>
    ${content}
</body>
</html>`;

// Convert privacy.md
const privacyMd = fs.readFileSync('privacy.md', 'utf8');
const privacyHtml = marked(privacyMd);
fs.writeFileSync('privacy.html', template('Privacy Policy', privacyHtml));

// Convert terms.md
const termsMd = fs.readFileSync('terms.md', 'utf8');
const termsHtml = marked(termsMd);
fs.writeFileSync('terms.html', template('Terms and Conditions', termsHtml));

console.log('✅ Converted markdown files to HTML');
