use bevy::prelude::*;
use bevy::input::mouse::AccumulatedMouseMotion;
use bevy::window::{CursorGrabMode, PrimaryWindow};

#[derive(Component)]
struct Player;

fn main() {
    App::new()
        .insert_resource(ClearColor(Color::srgb(0.08, 0.09, 0.12)))
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Bevy Game".into(),
                // The following only matter on the web build:
                canvas: Some("#bevy".into()),
                fit_canvas_to_parent: true,
                prevent_default_event_handling: false,
                ..default()
            }),
            ..default()
        }))
        .add_systems(Startup, (setup, grab_cursor))
        .add_systems(Update, (look, walk))
        .run();
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    commands.spawn((
        Mesh3d(meshes.add(Capsule3d::new(0.4, 1.0))),
        MeshMaterial3d(materials.add(Color::srgb(0.2, 0.6, 0.9))),
        Transform::from_xyz(0.0,0.9,0.0),
    ));
    commands.spawn((
        PointLight { shadows_enabled: true, ..default() },
        Transform::from_xyz(4.0, 8.0, 4.0),
    ));

    commands.spawn((
        Player,
        Camera3d::default(),
        Transform::from_xyz(0.0, 1.7, 5.0),
    ));
}

fn walk(
    keys: Res<ButtonInput<KeyCode>>,
    time: Res<Time>,
    mut query: Query<&mut Transform, With<Player>>,
) {
    let Ok(mut transform) = query.single_mut() else { return };

    let f = *t.forward();
    let r = *t.right();
    let forward = Vec3::new(f.x, 0.0, f.z).normalize_or_zero();
    let right   = Vec3::new(r.x, 0.0, r.z).normalize_or_zero();

    let mut dir = Vec3::ZERO;
    if keys.pressed(KeyCode::KeyW) { dir += forward; }
    if keys.pressed(KeyCode::KeyS) { dir -= forward; }
    if keys.pressed(KeyCode::KeyD) { dir += right; }
    if keys.pressed(KeyCode::KeyA) { dir -= right; }

    t.translation += dir.normalize_or_zero() * 5.0 * time.delta_secs();
}

fn look(
    motion: Res<AccumulatedMouseMotion>,
    mut query: Query<&mut Transform, With<Player>>,
) {
    let Ok(mut t) = query.single_mut() else { return };

    let (mut yaw, mut pitch, _) = t.rotation.to_euler(EulerRot::YXZ);
    let sens = 0.003;
    yaw   -= motion.delta.x * sens;  
    pitch -= motion.delta.y * sens;  
    pitch = pitch.clamp(-1.5, 1.5); 

    t.rotation = Quat::from_euler(EulerRot::YXZ, yaw, pitch, 0.0);
}

fn grab_cursor(mut window: Single<&mut Window, With<PrimaryWindow>>) {
    window.cursor_options.grab_mode = CursorGrabMode::Locked;
    window.cursor_options.visible = false;
}