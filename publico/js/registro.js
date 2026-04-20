import { sha256 } from './Hash.js';
const formulario = document.getElementById('form_registro');
formulario.addEventListener('submit', async function(event) {
    event.preventDefault();
    const datos = new FormData(formulario);
    const name = datos.get('UN').trim();
    const email = datos.get('EM').trim();
    const pass = datos.get('PW').trim();
    if (!name || !email || !pass) {
        alert('Todos los campos son obligatorios');
        return;
    }
    const passHash = await sha256(pass);
    const respuesta = await fetch('/api/registro', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            name: name,
            email: email,
            pass: passHash
        })
    });
    const resultado = await respuesta.json();
    if (resultado.success) {
        alert('Usuario registrado correctamente');
        window.location.href = '/login.html';
    } else {
        alert(resultado.message);
    }
});