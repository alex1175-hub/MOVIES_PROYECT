const formulario = document.getElementById('form_registro');

formulario.addEventListener('submit', async function (event) {
    event.preventDefault();

    const datos = new FormData(formulario);

    // ==============================
    // OBTENER VALORES
    // ==============================
    let name = datos.get('UN');
    let email = datos.get('EM');
    let pass = datos.get('PW');

    // ==============================
    // SANITIZAR DATOS
    // ==============================
    name = sanitizer.limpiarSeguro(name);
    email = sanitizer.limpiarEmail(email);
    pass = sanitizer.limpiarTexto(pass);

    // ==============================
    // VALIDACIÓN
    // ==============================
    if (!name || !email || !pass) {
        alert('Todos los campos son obligatorios o contienen datos inválidos');
        return;
    }

    try {
        // IMPORTANTE:
        // Ya NO se hace hash en frontend.
        // La contraseña se envía normal
        // y el backend hace el SHA-256.

        const respuesta = await fetch('/api/registro', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: name,
                email: email,
                pass: pass
            })
        });

        const resultado = await respuesta.json();

        if (resultado.success) {
            alert('Usuario registrado correctamente');
            window.location.href = '/login.html';
        } else {
            alert(resultado.message || 'Error al registrar usuario');
        }

    } catch (error) {
        console.error(error);
        alert('Error al conectar con el servidor');
    }
});