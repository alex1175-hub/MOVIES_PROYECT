const formulario = document.getElementById('form_login');

formulario.addEventListener('submit', async function (event) {
    event.preventDefault();

    const datos = new FormData(formulario);

    // ==============================
    // OBTENER VALORES
    // ==============================
    let name = datos.get('UN');
    let pass = datos.get('PW');

    // ==============================
    // SANITIZAR DATOS
    // ==============================
    name = sanitizer.limpiarSeguro(name);
    pass = sanitizer.limpiarTexto(pass);

    // ==============================
    // VALIDACIÓN
    // ==============================
    if (!name || !pass) {
        alert('Todos los campos son obligatorios');
        return;
    }

    try {
        const respuesta = await fetch('/api/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: name,
                pass: pass
            })
        });

        const resultado = await respuesta.json();

        if (resultado.success) {
            alert('Bienvenido');

            // Guardar ID en localStorage
            localStorage.setItem("id", resultado.user.id);

            // Redirección según rango
            if (resultado.user.rank === 'admin' || resultado.user.rank === 'master') 
            {
                window.location.href = '/admin.html';

            } else if (resultado.user.rank === 'resen') {
                window.location.href = '/resena.html';

            } else if (resultado.user.rank === 'user') {
                window.location.href = '/user.html';
            }

        } else {
            alert('Usuario o contraseña incorrectos');
        }

    } catch (error) {
        console.error(error);
        alert('Error al conectar con el servidor');
    }
});