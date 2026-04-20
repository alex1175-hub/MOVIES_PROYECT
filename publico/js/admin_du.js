const contenedor = document.getElementById('preview_usuarios');
contenedor.addEventListener('click', async function(event) {
    if (event.target && event.target.name === 'btnDU') {
        const Did = event.target.value;
        const idA = localStorage.getItem('id');
        if(idA!==Did){
            const confirmar = confirm("¿Seguro que deseas eliminar este usuario?");
            if (!confirmar) return;
            try {
                const respuesta = await fetch('/api/delete_user', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        id: Did
                    })
                });
                const resultado = await respuesta.json();
                if (resultado.success) {
                    alert(resultado.message);
                    location.reload();
                } else {
                    alert(resultado.message);
                }
            } catch (error) {
                console.error(error);
                alert("Error al eliminar usuario");
            }
        }else{
            alert("no puedes eliminarte a ti mismo");
        }
    }
});