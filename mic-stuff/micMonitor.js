#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

// Path to the MicMonitor executable
const micMonitorPath = path.join(__dirname, 'MicMonitor', 'build', 'Release', 'MicMonitor');

console.log('🎤 Starting MicMonitor Integration Test');
console.log('📍 Executable path:', micMonitorPath);
console.log('⏳ Starting microphone monitoring...');
console.log('💡 Try using your microphone (e.g., start a voice call, record audio) to see events');
console.log('🛑 Press Ctrl+C to stop monitoring\n');

// Start the MicMonitor process
const micMonitor = spawn(micMonitorPath, ['-j'], {
    stdio: ['pipe', 'pipe', 'pipe']
});

// Handle stdout data (JSON events)
micMonitor.stdout.on('data', (data) => {
    const lines = data.toString().split('\n');
    
    lines.forEach(line => {
        const trimmedLine = line.trim();
        if (trimmedLine) {
            try {
                // Try to parse as JSON
                const event = JSON.parse(trimmedLine);
                
                // Format and display the event
                console.log('🔔 MICROPHONE EVENT DETECTED:');
                console.log(`   📅 Time: ${event.timestamp}`);
                console.log(`   🎯 Event: ${event.event}`);
                console.log(`   🎙️  Device: ${event.device}`);
                
                if (event.process) {
                    console.log(`   📱 Process: ${event.process.name} (PID: ${event.process.pid})`);
                    console.log(`   📂 Path: ${event.process.path}`);
                }
                
                console.log('   ' + '─'.repeat(50));
                
            } catch (error) {
                // Not JSON, might be debug output - show it anyway
                console.log('🔍 Debug:', trimmedLine);
            }
        }
    });
});

// Handle stderr data (debug/error messages)
micMonitor.stderr.on('data', (data) => {
    const message = data.toString().trim();
    if (message && !message.includes('Class OSLogEvent')) { // Filter out duplicate class warnings
        console.log('⚠️  Debug:', message);
    }
});

// Handle process errors
micMonitor.on('error', (error) => {
    console.error('❌ Error starting MicMonitor:', error.message);
    
    if (error.code === 'ENOENT') {
        console.error('💡 Make sure MicMonitor is built. Run:');
        console.error('   cd MicMonitor && xcodebuild -project MicMonitor.xcodeproj -target MicMonitor -configuration Release build');
    }
});

// Handle process exit
micMonitor.on('close', (code) => {
    console.log(`\n🏁 MicMonitor stopped with exit code: ${code}`);
    process.exit(code);
});

// Handle Ctrl+C gracefully
process.on('SIGINT', () => {
    console.log('\n🛑 Stopping MicMonitor...');
    micMonitor.kill('SIGTERM');
});
