const express = require('express');
const path = require('path');
const mongoose = require('mongoose');

const app = express();

// ==============================
// CONFIGURACIÓN GENERAL
// ==============================

// Servir archivos estáticos
app.use(express.static(path.join(__dirname, 'publico')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const PORT = 8080;

// ==============================
// CONEXIÓN A MONGODB
// ==============================

mongoose.connect('mongodb://127.0.0.1:27017/TIRN_BD')
    .then(() => console.log('Conectado a MongoDB'))
    .catch(err => console.error(err));

// ==============================
// MODELOS
// ==============================

const MovieSchema = new mongoose.Schema({
    name: String,
    year: Number,
    director: String,
    review: String,
    actors: [String]
});

const UserSchema = new mongoose.Schema({
    name: String,
    contra: String,
    email: String,
    rank: String
});

const Movie = mongoose.model('Movies', MovieSchema, 'Movies');
const User = mongoose.model('Users', UserSchema, 'Users');

// ==============================
// RUTAS GENERALES
// ==============================

// Obtener lista simple de películas
app.get('/movies', async (req, res) => {
    try {
        const movies = await Movie.find({}, '_id name');
        res.json(movies);
    } catch (error) {
        res.status(500).json({
            error: 'Error al obtener películas'
        });
    }
});

// Obtener lista simple de usuarios
app.get('/users', async (req, res) => {
    try {
        const users = await User.find({}, '_id name');
        res.json(users);
    } catch (error) {
        res.status(500).json({
            error: 'Error al obtener usuarios'
        });
    }
});

// ==============================
// LOGIN
// ==============================

app.post('/api/login', async (req, res) => {
    const { name, pass } = req.body;

    try {
        const usuario = await User.findOne(
            {
                name: name,
                contra: pass
            },
            '_id rank'
        );

        if (usuario) {
            return res.json({
                success: true,
                user: {
                    id: usuario._id,
                    rank: usuario.rank
                }
            });
        }

        res.json({
            success: false,
            message: 'Credenciales incorrectas'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// ==============================
// REGISTRO DE USUARIOS
// ==============================

// Registro normal
app.post('/api/registro', async (req, res) => {
    const { name, email, pass, rank } = req.body;

    try {
        const existe = await User.findOne({
            $or: [
                { name: name },
                { email: email }
            ]
        });

        if (existe) {
            return res.json({
                success: false,
                message: 'El usuario ya existe'
            });
        }

        const nuevoUsuario = new User({
            name: name,
            email: email,
            contra: pass,
            rank: rank || 'user'
        });

        await nuevoUsuario.save();

        res.json({
            success: true,
            message: 'Usuario registrado correctamente'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// Registro desde admin
app.post('/api/admin_nu', async (req, res) => {
    const { name, email, pass, rank } = req.body;

    try {
        const existe = await User.findOne({
            $or: [
                { name: name },
                { email: email }
            ]
        });

        if (existe) {
            return res.json({
                success: false,
                message: 'El usuario ya existe'
            });
        }

        const nuevoUsuario = new User({
            name: name,
            email: email,
            contra: pass,
            rank: rank
        });

        await nuevoUsuario.save();

        res.json({
            success: true,
            message: 'Usuario registrado correctamente'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// ==============================
// USUARIOS - CONSULTAR / EDITAR / ELIMINAR
// ==============================

// Obtener usuario por ID
app.get('/api/user/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const user = await User.findById(id);

        if (!user) {
            return res.json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        res.json({
            success: true,
            user: user
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// Editar usuario
app.post('/api/edit_user', async (req, res) => {
    const { id, name, email, pass, rank } = req.body;

    try {
        const usuario = await User.findById(id);

        if (!usuario) {
            return res.json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        const existe = await User.findOne({
            _id: { $ne: id },
            $or: [
                { name: name },
                { email: email }
            ]
        });

        if (existe) {
            return res.json({
                success: false,
                message: 'El nombre o email ya está en uso'
            });
        }

        const nuevaContra =
            pass && pass.trim() !== ''
                ? pass
                : usuario.contra;

        await User.findByIdAndUpdate(id, {
            name: name,
            email: email,
            contra: nuevaContra,
            rank: rank
        });

        res.json({
            success: true,
            message: 'Usuario actualizado correctamente'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// Eliminar usuario
app.post('/api/delete_user', async (req, res) => {
    const { id } = req.body;

    try {
        const usuario = await User.findById(id);

        if (!usuario) {
            return res.json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        if (usuario.rank === 'master') {
            return res.json({
                success: false,
                message: 'No se puede eliminar un usuario master'
            });
        }

        await User.findByIdAndDelete(id);

        res.json({
            success: true,
            message: 'Usuario eliminado correctamente'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// ==============================
// PELÍCULAS - CONSULTAR
// ==============================

// Obtener película por ID
app.get('/api/movie/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const movie = await Movie.findById(id);

        if (!movie) {
            return res.json({
                success: false,
                message: 'Película no encontrada'
            });
        }

        res.json({
            success: true,
            movie: movie
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// Buscar película por nombre
app.get('/api/movie/name/:name', async (req, res) => {
    try {
        const movie = await Movie.findOne({
            name: new RegExp(req.params.name, 'i')
        });

        if (!movie) {
            return res.json({
                success: false,
                message: 'Película no encontrada'
            });
        }

        res.json({
            success: true,
            movie: movie
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// ==============================
// PELÍCULAS - CRUD
// ==============================

// Crear película
app.post('/api/movies', async (req, res) => {
    const { name, year, director, review, actors } = req.body;

    try {
        const nueva = new Movie({
            name,
            year,
            director,
            review,
            actors
        });

        await nueva.save();

        res.json({
            success: true,
            message: 'Película guardada correctamente'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error al guardar película'
        });
    }
});

// Actualizar película
app.put('/api/movies/:id', async (req, res) => {
    const { id } = req.params;

    try {
        await Movie.findByIdAndUpdate(id, req.body);

        res.json({
            success: true,
            message: 'Película actualizada correctamente'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error al actualizar película'
        });
    }
});

// Eliminar película
app.delete('/api/movies/:id', async (req, res) => {
    const { id } = req.params;

    try {
        await Movie.findByIdAndDelete(id);

        res.json({
            success: true,
            message: 'Película eliminada correctamente'
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error al eliminar película'
        });
    }
});

// ==============================
// INICIAR SERVIDOR
// ==============================

app.listen(PORT, () => {
    console.log(`Servidor corriendo en http://localhost:${PORT}`);
});