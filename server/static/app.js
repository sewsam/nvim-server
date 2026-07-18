// Global client instance
const client = new NeovimClient();
globalThis.client = client;

// Setup keyboard handlers
client.setupKeyboardHandlers();

// Window load handler
globalThis.addEventListener("load", () => {
    client.connect();

    // Make sure the bundled Nerd Font is loaded before the canvas paints icon
    // glyphs; once ready, force a redraw so the first frame isn't a fallback font.
    if (globalThis.document && document.fonts && document.fonts.load) {
        document.fonts.load('14px "JetBrainsMono Nerd Font"').then(() => {
            if (client.renderer) client.renderer.redraw();
        }).catch(() => {});
    }

    // Auto-connect to the co-located Neovim by default so the app is zero-click.
    // A ?server= query param overrides the built-in default when set.
    const serverAddress = getUrlParameter("server") || "127.0.0.1:6666";
    if (serverAddress && isValidServerAddress(serverAddress)) {
        const connectionForm = document.getElementById("connection-form");
        if (connectionForm) {
            connectionForm.style.opacity = "0.5";
        }

        const addressInput = document.getElementById("nvim-address");
        if (addressInput) {
            addressInput.value = decodeURIComponent(serverAddress);
        }

        setTimeout(() => {
            client.updateStatus("Auto-connecting to " + serverAddress + "...");
            client.updateTitle(serverAddress + " (connecting...)");
            client.updateFavicon("default");
            client.connectToNeovim(decodeURIComponent(serverAddress));
        }, 500);
    }
});

// Terminal event handlers
const terminal = document.getElementById("terminal");

terminal.addEventListener("keyup", (_event) => {
    if (!client.connected) return;
});

terminal.addEventListener("paste", (event) => {
    if (!client.connected) return;

    event.preventDefault();
    const text = event.clipboardData.getData("text");
    client.sendInput(text);
});

// Global connection function
globalThis.connectToNeovim = function () {
    const addressInput = document.getElementById("nvim-address");
    if (!addressInput) {
        console.error("Address input not found");
        return;
    }

    const address = addressInput.value;

    if (address.trim()) {
        client.connectToNeovim(address);
    } else {
        client.updateStatus("Please enter a valid address");
    }
};
