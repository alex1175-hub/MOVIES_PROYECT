import { sha256 } from './Hash.js';
const formulario = document.getElementById('form_login');
formulario.addEventListener('submit', async function(event) {
    event.preventDefault();
    const datos = new FormData(formulario);
    const name = datos.get('UN').trim();
    const pass = datos.get('PW').trim();
    const passHash = await sha256(pass);
    console.log(passHash);
    const respuesta = await fetch('/api/login', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name: name, pass: passHash })
    });
    const resultado = await respuesta.json();
    if (resultado.success) {
        alert('bienvenido');
        localStorage.setItem("id", resultado.user.id);
         if (resultado.user.rank === 'admin' || resultado.user.rank === 'master') {
            window.location.href = '/admin.html';
        } else if (resultado.user.rank === 'resen') {
            window.location.href = '/resena.html';
        } else if (resultado.user.rank === 'user') {
            window.location.href = '/user.html';
        }
    } else {
        alert('Correo o contraseña incorrectos');
    }
});
 