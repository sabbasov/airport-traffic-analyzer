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
            body { font-family: Arial, sans-serif; margin: 50px; line-height: 1.6; }
            h1 { color: #001f3f; }
            .container { max-width: 800px; }
            .feature { margin: 20px 0; padding: 15px; background: #f5f5f5; border-left: 4px solid #0066cc; }
            code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; }
            a { color: #0066cc; text-decoration: none; }
            a:hover { text-decoration: underline; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🛫 Airport Traffic Analyzer</h1>
            <p>Real-time flight delay monitoring and prediction system.</p>
            
            <h2>Features</h2>
            <div class="feature">
                <strong>📊 Interactive Dashboard</strong>
                <p>Shiny R application with real-time filtering and predictions.</p>
                <p><em>To run locally:</em> <code>Rscript shiny_app.R</code></p>
            </div>
            
            <div class="feature">
                <strong>🤖 ML Model</strong>
                <p>Random Forest regressor predicts departure delays (RMSE: 8.4 min)</p>
            </div>
            
            <div class="feature">
                <strong>📈 Data Pipeline</strong>
                <p>Python script fetches real flight and weather data via APIs.</p>
                <p><em>To run:</em> <code>python scripts/fetch_data.py</code></p>
            </div>
            
            <div class="feature">
                <strong>📋 Analytics Report</strong>
                <p>50+ visualizations of flight patterns and insights.</p>
                <p><em>To generate:</em> <code>quarto render analysis.qmd --to html</code></p>
            </div>
            
            <h2>Getting Started</h2>
            <ol>
                <li>Clone the repo: <code>git clone &lt;repo-url&gt;</code></li>
                <li>Run setup: <code>./setup.sh full</code></li>
                <li>Launch dashboard: <code>./setup.sh dashboard</code></li>
            </ol>
            
            <p><strong>📚 See the <a href="https://github.com/sabbasov/airport-traffic-analyzer">GitHub repo</a> for full documentation.</strong></p>
        </div>
    </body>
    </html>
    '''

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
