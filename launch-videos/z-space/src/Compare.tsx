import React from "react";
import { AbsoluteFill } from "remotion";
import { fontCss, SCREEN_W, SCREEN_H } from "./theme";
import { SESSION, SessionBase, SessionHeader, RightTabs, Chat, Composer, Desktop, LiveControls } from "./ui/Session";
import { HOME, HomeBase, HomeCard, HomeControls, HomeLogo, HomeToggle, EnvMenu, EnvPicker } from "./ui/Home";

const Abs: React.FC<{ r: { x: number; y: number; w: number; h: number }; children: React.ReactNode }> = ({ r, children }) => (
  <div style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h }}>{children}</div>
);

export const HomeFlat: React.FC<{ menu?: boolean; mac?: boolean }> = ({ menu, mac }) => (
  <div style={{ position: "absolute", width: SCREEN_W, height: SCREEN_H }}>
    <HomeBase />
    <Abs r={HOME.logo}><HomeLogo /></Abs>
    <Abs r={HOME.toggle}><HomeToggle /></Abs>
    <Abs r={HOME.card}><HomeCard text="" focused={false} frame={40} /></Abs>
    <Abs r={HOME.controls}><HomeControls active={false} pressed={0} /></Abs>
    <Abs r={HOME.env}><EnvPicker mac={!!mac} /></Abs>
    {menu ? <Abs r={HOME.menu}><EnvMenu hoverMac={0} mac={!!mac} /></Abs> : null}
  </div>
);

export const SessionFlat: React.FC = () => (
  <div style={{ position: "absolute", width: SCREEN_W, height: SCREEN_H }}>
    <SessionBase />
    <Abs r={SESSION.header}><SessionHeader title="Create Otter Flappy Bird iOS App" /></Abs>
    <Abs r={SESSION.tabs}><RightTabs computer={1} /></Abs>
    <Abs r={SESSION.chat}><Chat frame={0} replyChars={200} rows={6} collapsed={0} status="build" /></Abs>
    <Abs r={SESSION.composer}><Composer running /></Abs>
    <Abs r={SESSION.desktop}><Desktop startFrom={30} /></Abs>
    <Abs r={SESSION.live}><LiveControls progress={0.995} /></Abs>
  </div>
);

export const Compare: React.FC<{ which: string }> = ({ which }) => (
  <AbsoluteFill style={{ background: "#fff" }}>
    <style>{fontCss}</style>
    <div style={{ position: "absolute", left: 0, top: 0, transformOrigin: "0 0", transform: `scale(${1882 / SCREEN_W})` }}>
      {which === "home" ? <HomeFlat menu /> : null}
      {which === "session" ? <SessionFlat /> : null}
    </div>
  </AbsoluteFill>
);
