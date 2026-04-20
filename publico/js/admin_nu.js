import { sha256 } from './Hash.js';
const formulario = document.getElementById('form_nu');
formulario.addEventListener('submit', async function(event) {
    event.preventDefault();
    const datos = new FormData(formulario);
    const name = datos.get('UN').trim();
    const email = datos.get('EM').trim();
    const pass = datos.get('PW').trim();
    const rank = datos.get('RK').trim();
    if (!name || !email || !pass || !rank) {
        alert('Todos los campos son obligatorios');
        return;
    }
    const passHash = await sha256(pass);
    const respuesta = await fetch('/api/admin_nu', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            name: name,
            email: email,
            pass: passHash,
            rank: rank
        })
    });
    const resultado = await respuesta.json();
    if (resultado.success) {
        alert('Usuario creado correctamente');
        window.location.href = '/admin.html';
    } else {
        alert(resultado.message);
    }
});