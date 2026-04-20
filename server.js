const express = require('express');
const path = require('path');
const mongoose = require('mongoose');

const app = express();

// Servir archivos estáticos
app.use(express.static(path.join(__dirname, 'publico')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const PORT = 8080;

// Conexion a MongoDB
mongoose.connect('mongodb://127.0.0.1:27017/TIRN_BD')
    .then(() => console.log('Conectado a MongoDB'))
    .catch(err => console.error(err));

// modelos
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

// rutas
app.get('/movies', async (req, res) => {
    try {
        const movies = await Movie.find({}, '_id name');
        res.json(movies);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener datos' });
    }
});

app.get('/users', async (req, res) => {
    try {
        const USERS = await User.find({}, '_id name');
        res.json(USERS);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener datos' });
    }
});

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

app.post('/api/login', async (req, res) => {
    const { name, pass } = req.body;

    try {
        const usuario = await User.findOne(
            { name: name, contra: pass },
            '_id rank'
        );

        if (usuario) {
            res.json({
                success: true,
                user: {
                    id: usuario._id,
                    rank: usuario.rank
                }
            });
        } else {
            res.json({ success: false, message: 'Credenciales incorrectas' });
        }

    } catch (error) {
        res.status(500).json({ error: 'Error en el servidor' });
    }
});

app.post('/api/registro', async (req, res) => {
    const { name, email, pass, rank } = req.body;
    try {
        // Verificar si ya existe usuario
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
        // Crear nuevo usuario
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

app.post('/api/admin_nu', async (req, res) => {
    const { name, email, pass, rank } = req.body;
    try {
        // Verificar si ya existe usuario
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
        // Crear nuevo usuario
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

app.post('/api/delete_user', async (req, res) => {
    const { id } = req.body;
    try {
        // Buscar usuario por id
        const usuario = await User.findById(id);
        if (!usuario) {
            return res.json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }
        // Verificar si es master
        if (usuario.rank === 'master') {
            return res.json({
                success: false,
                message: 'No se puede eliminar un usuario master'
            });
        }
        // Eliminar usuario
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

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`Servidor corriendo en http://localhost:${PORT}`);
});
