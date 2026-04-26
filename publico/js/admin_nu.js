const formulario = document.getElementById('form_nu');

formulario.addEventListener('submit', async function (event) {
    event.preventDefault();

    const datos = new FormData(formulario);

    // ==============================
    // OBTENER VALORES
    // ==============================

    let name = datos.get('UN');
    let email = datos.get('EM');
    let pass = datos.get('PW');
    let rank = datos.get('RK');

    // ==============================
    // SANITIZAR DATOS
    // ==============================

    name = sanitizer.limpiarSeguro(name);
    email = sanitizer.limpiarEmail(email);
    pass = sanitizer.limpiarTexto(pass); // contraseña en texto plano
    rank = sanitizer.limpiarSeguro(rank);

    // ==============================
    // VALIDACIÓN
    // ==============================

    if (!name || !email || !pass || !rank) {
        alert('Todos los campos son obligatorios o contienen datos inválidos');
        return;
    }

    try {
        // ==============================
        // ENVIAR AL BACKEND
        // ==============================

        const respuesta = await fetch('/api/admin_nu', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: name,
                email: email,
                pass: pass,
                rank: rank
            })
        });

        const resultado = await respuesta.json();

        if (resultado.success) {
            alert('Usuario creado correctamente');
            window.location.href = '/admin.html';
        } else {
            alert(resultado.message || 'Error al crear usuario');
        }

    } catch (error) {
        console.error(error);
        alert('Error al conectar con el servidor');
    }
});