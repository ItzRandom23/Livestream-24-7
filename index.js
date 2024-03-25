const express = require('express')
const app = express()
const port = 3000

app.get('/', (req, res) => {
  res.send('Your Live Stream Is Online Now!')
})

app.listen(port, () => {
  console.log(`Your Live Stream Is Running..`)
})

const { exec } = require('child_process');
var yourscript = exec('sh live.sh',
        (error, stdout, stderr) => {
            console.log(stdout);
            console.log(stderr);
            if (error !== null) {
                console.log(`exec error: ${error}`);
            }
        });

