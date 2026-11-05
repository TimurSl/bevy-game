use bevy::prelude::*;

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
        .add_systems(Startup, setup)
        .run();
}

fn setup(mut commands: Commands) {
    commands.spawn(Camera2d);
    
    commands.spawn((
        Sprite::from_color(
            Color::srgb(0.9, 0.3, 0.3), 
            Vec2::new(100.0, 100.0)
        ), 
        Transform:from_xyz(0.0,0.0,0.0),
    ));
}
