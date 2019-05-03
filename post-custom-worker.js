self.onmessage = function(e) {
    var msg = e.data;

    if (msg["type"] == "run") {
        console.log('run called');

        var opts = {
            arguments: msg['args'],

            mounts: msg['mounts'],

            //print: function(data) { stdout += data + "\n"; },
            //printErr: function(data) { stderr += data + "\n"; },

            stdoutBinary: function(data) {
                self.postMessage({
                    "type": "binary",
                    "data": data
                });
            },

            stdout: function(data) {
                self.postMessage({
                    "type": "stdout",
                    "data": String.fromCharCode(data)
                });
            },

            stderr: function(data) {
                // ffmpeg sends text log to stderr so that stdout can be used for streaming output
                self.postMessage({
                    "type": "stderr",
                    "data": String.fromCharCode(data)
                });
            },

            onExit: function(code) {
                self.postMessage({
                    "type": "exit",
                    "data": code
                });
            },

            onAbort: function(code) {
                self.postMessage({
                    "type": "abort",
                    "data": code
                });
            },

            stdin: function() {
                // not used
            },

            postRunCallback: function(data) {
                self.postMessage({
                    "type": "done",
                    "data": data
                });
            }
        };

        aconv(opts);
    }
};
