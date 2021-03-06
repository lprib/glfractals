#version 420

uniform vec2 resolution;
uniform vec2 mousePos;
out vec4 color;

#define PI 3.1415926538

const float NORM_EPSILON = 0.0001;
const int TRACE_MAX_ITERS = 40;
// distance to the scene where a ray will be considered a hit
const float TRACE_HIT_DIST = 0.001;

const int JULIA_ITERS = 15;
const vec4 c = vec4(0.2, 0.0, 0.8, 0.6);


// void main() { color = vec4(camAngle / 8.0, 0.0, 0.0, 1.0); }

float mandelbulb(vec3 pos);
float julia(vec3 pos);

struct Ray {
  vec3 pos;
  vec3 dir;
};

struct TraceResult {
  bool hit;
  vec3 pos;
  float dist;
};

vec3 camRayDir(vec2 uv, vec3 camPos, vec3 lookAt, float zoom) {
  vec3 look_dir = normalize(lookAt - camPos);
  vec3 right_vec = normalize(cross(vec3(0.0, 1.0, 0.0), look_dir));
  vec3 up_vec = cross(look_dir, right_vec);
  vec3 zoomed_cam_pos = camPos + look_dir * zoom;
  vec3 pixel_pos = zoomed_cam_pos + uv.x * right_vec + uv.y * up_vec;
  return pixel_pos - camPos;
}

float smoothMin(float a, float b) {
  float k = 0.2;
  float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
  return mix(a, b, h) - k * h * (1.0 - h);
}

float distToScene(vec3 p) {
  return julia(p);
  // return length(p - vec3(0.0, 0.0, 0.0)) - 0.3;
  // return smoothMin(
  //     p.z,
  //     smoothMin(p.x, smoothMin(p.y, length(p - vec3(0.3, 0.2, 0.6)) -
  //   0.3)));
}

vec3 estimateNormal(vec3 p) {
    float xPl = distToScene(vec3(p.x + NORM_EPSILON, p.y, p.z));
    float xMi = distToScene(vec3(p.x - NORM_EPSILON, p.y, p.z));
    float yPl = distToScene(vec3(p.x, p.y + NORM_EPSILON, p.z));
    float yMi = distToScene(vec3(p.x, p.y - NORM_EPSILON, p.z));
    float zPl = distToScene(vec3(p.x, p.y, p.z + NORM_EPSILON));
    float zMi = distToScene(vec3(p.x, p.y, p.z - NORM_EPSILON));
    float xDiff = xPl - xMi;
    float yDiff = yPl - yMi;
    float zDiff = zPl - zMi;
    return normalize(vec3(xDiff, yDiff, zDiff));
  // vec3 eps = vec3(0.001, 0.0, 0.0);
  // vec3 nor = vec3(distToScene(p + eps.xyy).x - distToScene(p - eps.xyy).x,
  //                 distToScene(p + eps.yxy).x - distToScene(p - eps.yxy).x,
  //                 distToScene(p + eps.yyx).x - distToScene(p - eps.yyx).x);
  // return normalize(nor);
}

TraceResult traceRay(Ray r) {
  float totalDist = 0.0;
  float finalDist = distToScene(r.pos);
  vec3 position = r.pos;

  for (int iters = 0; iters < TRACE_MAX_ITERS; iters++) {
    position += finalDist * r.dir;
    totalDist += finalDist;
    finalDist = distToScene(position);
    if (finalDist < TRACE_HIT_DIST) {
      return TraceResult(true, position, totalDist);
    }
  }

  return TraceResult(false, vec3(0.0), 0.0);
}

void main() {
  vec2 uv = gl_FragCoord.xy / resolution.xy;
  // offset, so center of screen is origin
  uv -= vec2(0.5);
  // scale, so there is no rectangular distortion
  uv.x *= resolution.x / resolution.y;

  // vec3 camPos = vec3(4.0 * cos(camAngle), 0.0, 4.0 * sin(camAngle));
  // TODO there is distortion near center of screen when camera is too far away from the object, WHY?
  vec3 camPos = vec3(2.0*cos(2.0*PI*mousePos.x), 1.0, 2.0*sin(2.0*PI*mousePos.x));
  vec3 lookAt = vec3(0.0, 0.0, 0.0);
  float zoom = 1.0;

  Ray camRay = Ray(camPos, camRayDir(uv, camPos, lookAt, zoom));
  TraceResult res = traceRay(camRay);

  if (res.hit) {
    vec3 normal = estimateNormal(res.pos);
    vec3 lightPos = vec3(2.0, 1.0, 1.0);
    float sDotN = dot(normal, normalize(lightPos - res.pos));
    color = vec4(vec3(normal), 1.0);
  } else {
    color = vec4(0.0, 0.0, 0.0, 1.0);
  }
}

vec4 quatMul(vec4 a, vec4 b) {
  return vec4(a.x * b.x - dot(a.yzw, b.yzw),
              a.x * b.yzw + b.x * a.yzw + cross(a.yzw, b.yzw));
}

int iters = 15;
float bailout = 2.0;
float power = 3;

float mandelbulb(vec3 pos) {
  power = mousePos.y*20.0;
  vec3 z = pos;
  float dr = 1.0;
  float r = 0.0;
  for (int i = 0; i < iters; i++) {
    r = length(z);
    if (r > bailout)
      break;
    float theta = acos(z.z / r);
    float phi = atan(z.y, z.x);
    dr = pow(r, power - 1.0) * power * dr + 1.0;

    float zr = pow(r, power);
    theta = theta * power;
    phi = phi * power;

    z = zr * vec3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
    z += pos;
  }
  return 0.5 * log(r) * r / dr;
}

float julia(vec3 pos) {
  vec4 z = vec4(pos, 3.0*mousePos.y - 1.5);
  vec4 dz = vec4(1.0, 0.0, 0.0, 0.0);
  int count = 0;

  while(count < JULIA_ITERS) {
    vec4 zNew = quatMul(z, z) + c;
    dz = 2.0*quatMul(z, dz);
    z = zNew;

    if(length(z) > 4.0) {
      break;
    }
    count += 1;
  }

  return 0.6*length(z)*log(length(z))/length(dz);
}