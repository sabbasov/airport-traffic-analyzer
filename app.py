from flask import Flask
import subprocess
import os

app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Airport Traffic Analyzer</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 50px; }
            h1 { color: #001f3f; }
            a { color: #0066cc; text-decoration: none; }
            a:hover { text-decoration: underline; }
        </style>
    </head>
    <body>
        <h1>🛫 Airport Traffic Analyzer</h1>
        <p>Real-time flight delay monitoring and prediction system.</p>
        <p><a href="/dashboard">Launch Interactive Dashboard</a></p>
        <p><strong>Note:</strong> The dashboard is a Shiny R application running locally.</p>
        <p>To start the Shiny app manually, run: <code>Rscript shiny_app.R</code></p>
    </body>
    </html>
    '''

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
