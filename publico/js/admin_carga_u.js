const Name = document.querySelector('input[name="UN"]');
const Email = document.querySelector('input[name="EM"]');
const Pass = document.querySelector('input[name="PW"]');
const Rank = document.querySelectorAll('input[name="RK"]');
const id_u = localStorage.getItem('id_ue');
if (!id_u) {
    console.log("No se encontró el ID del usuario");
} else {
    fetch(`/api/user/${id_u}`)
        .then(response => response.json())
        .then(data => {
            if (!data.success) {
                console.log(data.message);
                return;
            }
            Name.value = data.user.name || '';
            Email.value = data.user.email || '';
            Pass.value = ''; // por seguridad no se muestra hash
            Rank.forEach(radio => {
                if (radio.value === data.user.rank) {
                    radio.checked = true;
                }
            });
        })
        .catch(error => {
            console.error("Error:", error);
        });
}