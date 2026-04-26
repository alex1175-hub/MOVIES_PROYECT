export async function sha256(texto) {
    const cryptoObj = window.crypto || window.msCrypto;
    if (!cryptoObj || !cryptoObj.subtle) {
        throw new Error("Web Crypto API no disponible en este navegador o conexión");
    }
    const encoder = new TextEncoder();
    const data = encoder.encode(texto);
    const hashBuffer = await cryptoObj.subtle.digest("SHA-256", data);
    return Array.from(new Uint8Array(hashBuffer))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('');
}