export function sha256(texto) {
    const encoder = new TextEncoder();
    const pass = encoder.encode(texto);

    return crypto.subtle.digest("SHA-256", pass)
        .then(buffer => {
            return Array.from(new Uint8Array(buffer))
                .map(b => b.toString(16).padStart(2, '0'))
                .join('');
        });
}