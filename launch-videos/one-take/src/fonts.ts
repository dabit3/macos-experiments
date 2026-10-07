import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadRobotoMono } from "@remotion/google-fonts/RobotoMono";
import { loadFont as loadNunito } from "@remotion/google-fonts/Nunito";

const inter = loadInter("normal", { weights: ["400", "500", "600"], subsets: ["latin"] });
const robotoMono = loadRobotoMono("normal", { weights: ["400"], subsets: ["latin"] });
const nunito = loadNunito("normal", { weights: ["800", "900"], subsets: ["latin"] });

export const sans = `${inter.fontFamily}, -apple-system, 'Helvetica Neue', Arial, sans-serif`;
export const mono = `${robotoMono.fontFamily}, 'SF Mono', Menlo, monospace`;
export const rounded = `${nunito.fontFamily}, ${inter.fontFamily}, sans-serif`;
