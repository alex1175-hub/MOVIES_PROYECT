import { sha256 } from './Hash.js';
const id_u = localStorage.getItem('id_ue');
const formulario = document.getElementById('form_eu');
formulario.addEventListener('submit', async function (event) {
    event.preventDefault();
    if (!id_u) {
        alert('No se encontró el ID del usuario');
        return;
    }
    const datos = new FormData(formulario);
    const name = datos.get('UN').trim();
    const email = datos.get('EM').trim();
    const pass = datos.get('PW').trim();
    const rank = datos.get('RK').trim();
    if (!name || !email || !rank) {
        alert('Nombre, email y rango son obligatorios');
        return;
    }
    let passFinal = '';
    if (pass !== '') {
        passFinal = await sha256(pass);
    }
    const respuesta = await fetch('/api/edit_user', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: id_u,
            name: name,
            email: email,
            pass: passFinal,
            rank: rank
        })
    });
    const resultado = await respuesta.json();
    if (resultado.success) {
        alert('Usuario editado correctamente');
        localStorage.removeItem('id_ue');
        window.location.href = '/admin.html';
    } else {
        alert(resultado.message);
    }
});