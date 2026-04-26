const id_u = localStorage.getItem('id_ue');
const formulario = document.getElementById('form_eu');

formulario.addEventListener('submit', async function (event) {
    event.preventDefault();

    // ==============================
    // VALIDAR ID
    // ==============================

    if (!id_u) {
        alert('No se encontró el ID del usuario');
        return;
    }

    // ==============================
    // OBTENER DATOS
    // ==============================

    const datos = new FormData(formulario);

    let name = datos.get('UN');
    let email = datos.get('EM');
    let pass = datos.get('PW');
    let rank = datos.get('RK');

    // ==============================
    // SANITIZAR
    // ==============================

    name = sanitizer.limpiarSeguro(name);
    email = sanitizer.limpiarEmail(email);
    pass = sanitizer.limpiarTexto(pass); // texto plano
    rank = sanitizer.limpiarSeguro(rank);

    // ==============================
    // VALIDACIÓN
    // ==============================

    if (!name || !email || !rank) {
        alert('Nombre, email y rango son obligatorios');
        return;
    }

    try {
        // ==============================
        // ENVIAR AL BACKEND
        // El backend hará el hash si pass existe
        // ==============================

        const respuesta = await fetch('/api/edit_user', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id: id_u,
                name: name,
                email: email,
                pass: pass, // texto plano
                rank: rank
            })
        });

        const resultado = await respuesta.json();

        if (resultado.success) {
            alert('Usuario editado correctamente');

            localStorage.removeItem('id_ue');
            window.location.href = '/admin.html';
        } else {
            alert(resultado.message || 'Error al editar usuario');
        }

    } catch (error) {
        console.error(error);
        alert('Error al conectar con el servidor');
    }
});