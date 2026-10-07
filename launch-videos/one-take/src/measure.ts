let ctx: CanvasRenderingContext2D | null = null;
const cache = new Map<string, number>();

export const measure = (text: string, font: string) => {
  const key = `${font}|${text}`;
  const hit = cache.get(key);
  if (hit !== undefined) return hit;
  if (!ctx) ctx = document.createElement("canvas").getContext("2d");
  if (!ctx) return text.length * 7;
  ctx.font = font;
  const w = ctx.measureText(text).width;
  cache.set(key, w);
  return w;
};
