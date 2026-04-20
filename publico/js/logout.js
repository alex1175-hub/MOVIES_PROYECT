document.addEventListener('DOMContentLoaded', () => {
    const boton = document.getElementById('logout');
    if (boton) {
        boton.addEventListener('click', () => {
            localStorage.removeItem('id');
            alert('sesion cerrada con exito');
            window.location.href = '/index.html';
        });
    }
});