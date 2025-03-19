const { exec } = require('child_process');
const scriptPath = "/workspaces/Livestream-24-7/live.sh"; // Update with the correct path

const yourscript = exec(`bash ${scriptPath}`, (error, stdout, stderr) => {
    if (error) {
        console.error(`Execution error: ${error.message}`);
        return;
    }
    console.log("Output:", stdout);
    console.error("Errors (if any):", stderr);
});

// Listen to stdout and stderr in real-time
yourscript.stdout.on('data', (data) => {
    console.log(`STDOUT: ${data}`);
    if (data.includes('STREAM_LIVE')) {
        console.log('Confirmation: Live stream has started successfully!');
    }
});

yourscript.stderr.on('data', (data) => {
    console.error(`STDERR: ${data}`);
});

yourscript.on('close', (code) => {
    console.log(`Child process exited with code ${code}`);
});