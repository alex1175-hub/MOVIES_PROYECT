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
        alert(`Login correcto\nUsuario: ${resultado.user.name}\nRango: ${resultado.user.rank}`);
    } else {
        alert('Correo o contraseña incorrectos');
    }
});