use std::f32::consts::PI;

use glium::{
    glutin::{self, dpi::PhysicalPosition},
    implement_vertex, uniform, Display, Surface,
};

#[derive(Copy, Clone)]
struct Vertex {
    position: [f32; 2],
}

implement_vertex!(Vertex, position);

fn main() {
    let mut event_loop = glutin::event_loop::EventLoop::new();
    let window_builder = glutin::window::WindowBuilder::new();
    let context_builder = glutin::ContextBuilder::new().with_vsync(true);
    let display = glium::Display::new(window_builder, context_builder, &event_loop).unwrap();

    let shape = vec![
        Vertex {
            position: [-1.0, -1.0],
        },
        Vertex {
            position: [-1.0, 1.0],
        },
        Vertex {
            position: [1.0, -1.0],
        },
        Vertex {
            position: [1.0, 1.0],
        },
    ];

    let vertex_buffer = glium::VertexBuffer::new(&display, &shape).unwrap();
    let indices = glium::index::NoIndices(glium::index::PrimitiveType::TriangleStrip);

    let vertex_shader_src = include_str!("vertex.glsl");
    let fragment_shader_src = include_str!("fragment.glsl");

    let program =
        glium::Program::from_source(&display, vertex_shader_src, fragment_shader_src, None)
            .unwrap_or_else(|e| {
                use glium::program::ProgramCreationError::*;
                match e {
                    CompilationError(msg, shader_type) => {
                        panic!("compilation error in {:?}\n{}", shader_type, msg)
                    }
                    LinkingError(msg) => panic!("linking error {}", msg),
                    _ => panic!("{:?}", e),
                }
            });

    let mut mouse = [0f32, 0f32];
    let mut camAngle = 0.0f32;

    event_loop.run(move |event, _, control_flow| {
        let mut target = display.draw();
        target.clear_color(0.0, 0.0, 1.0, 1.0);
        let (x, y) = display.get_framebuffer_dimensions();
        let (x, y) = (x as f32, y as f32);
        target
            .draw(
                &vertex_buffer,
                &indices,
                &program,
                &uniform! {resolution: [x, y], camAngle: camAngle},
                &Default::default(),
            )
            .unwrap();

        target.finish().unwrap();

        // let next_frame_time =
        //     std::time::Instant::now() + std::time::Duration::from_nanos(50_000_000);
        // *control_flow = glutin::event_loop::ControlFlow::WaitUntil(next_frame_time);

        match event {
            glutin::event::Event::WindowEvent {
                event: window_event,
                ..
            } => match window_event {
                glutin::event::WindowEvent::CloseRequested => {
                    *control_flow = glutin::event_loop::ControlFlow::Exit;
                    return;
                }
                glutin::event::WindowEvent::CursorMoved {
                    position: PhysicalPosition { x: mx, y: my },
                    ..
                } => {
                    camAngle = mx as f32 / x * 8.0;
                }
                _ => return,
            },
            _ => {}
        }
    })
}

fn set_mouse_pos(pos: &mut [f32; 2], display: &Display, x: f64, y: f64) {
    let (w, h) = display.get_framebuffer_dimensions();
    pos[0] = (x as f32 / w as f32) * 2.0 - 1.0;
    pos[1] = -((y as f32 / h as f32) * 2.0 - 1.0);
}
