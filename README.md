heyyy, ¿que tal?, pues aqui os traigo otro logro del compañero gemini, le he propuesto y le he dicho, porfaaa, ¿puedes hacer compatible counter-life con xash3d en linux? y gemini ha dicho "pues vamos p'alla" y ya ha hecho el milagro, ya que ha hecho un script automatizado que hace compatible este mod en linux, asi puedo proponer otra utilidad diferente de la IA para los programadores, que es tu haces el codigo compatible con windows, haces una copia de seguridad, pones a la IA que haga compatible tu codigo fuente de programa con linux, lo pruebas y si funciona, pues lo publicas aqui sin problema. bueno, no os entretengo mas, este es el mini-tutorial:

-----------------------------------------------------------------

descripcion:
mod de half-life que cambia las armas y las balas por dinero y los botiquines y la energia por el famoso menu de compra del CS:1.6.

------------------------------------------------------------------

requisitos:
half-life (se recomienda que sea el original si es un equipo en el cual solo se puede instalar linux o tu equipo es steam deck-steam machines) (OJO: si es el steam, el original solo se distribuye en 32 bits, con lo cual descargar xash3d de 32 bits junto con la copia del original en steam), (OJO: no se ha probado en mini-instalaciones de half-lifes no-steam, estas versiones de half-life solo estan disponibles bajo "windows maquetado" [wine], con lo cual es posible que no te funcione o funcione a medias, ya que este tipo de windows es muy diferente al windows de la maquina virtual o el windows instalado en el equipo tanto junto a linux como sin el, si no te funciona, tendras que ahorrar para comprarte la copia original de half-life [tendras acceso tanto al original como a los mods indistintamente si se ejecutan a traves de steam con el motor del 25 aniversario como el motor del pre, ademas de que si te pasa de que si o si necesitas linux, pues el juego lo puedes cargar en linux sin problema, eso si, avances se han conseguido y la IA ha acelerado dichos avances, pero todavia queda mucho para por ejemplo ver fortnite en linux])
las librerias siguientes:
libpulse0:i386 pipewire-alsa:i386 libspa-0.2-modules:i386 libc6:i386 libstdc++6:i386 libgcc-s1:i386 libgl1:i386 libgl1-mesa-dri:i386 libglx-mesa0:i386 libsdl2-2.0-0:i386 libasound2-plugins:i386 libpulse0:i386 libfontconfig1:i386 libfreetype6:i386 zlib1g:i386
el mod, obviamente, pero el original, ya que el parche lo tenemos que aplicar al mod original.
xash3d de 32 bits.

---------------------------------------------------------------------------
autores:
gemini - autor del parche
BENDER - verificacion de que funcione

DEMO:
en proceso de subida al yutubi

mini-tuto:
1.  descargar el mod: https://www.moddb.com/mods/counter-life/downloads/counter-life-version-1
2.  descargar xash3d, OJO, solo el de 32 bits: https://github.com/FWGS/xash3d-fwgs/releases/tag/continuous
3.  en un equipo linux (con mejores resultados si es windows), descargamos half-life de steam, nos iremos a la carpeta de half-life:
linux:
/home/USUARIO/.steam/steam/steamapps/common/half-life
o tambien:
 ~/.local/share/Steam/steamapps/common/
windows:
C:\Program Files (x86)\Steam\steamapps\common\
4.  ahora, abrid otro explorador, descomprimid xash3d, en entorno comando es el siguiente: tar -xzvf ARCHIVO_XASH3D.tar.gz, si es en entorno grafico, sigue los pasos establecidos en la distro.
5.  ahora turno para el mod, el comando es unzip -d /home/USUARIO/Descargas/DIRECTORIO_XASH3D ZIP_COUNTER-LIFE.zip.
6.  ahora con xash3d y el mod, atentos, teneis que copiar en un pen o transferir via SSH a tu equipo con linux (la transferencia se hace via filezilla) la carpeta valve completa al directorio de xash3d.
7.  ahora bajad el parche .sh
8.  hacedlo ejecutable, este si tiene que ser por comandos, el comando es chmod +x setup_counter_life_linux.sh
9.  ahora teclead ./setup_counter_life_linux.sh
10.  el script hara su trabajo, entre ellos descargar el SDK de half-life en la carpeta temporal (/tmp) y compilar los archivos necesarios para hacer compatible este mod.
11.  bien, ahora importante, instalad todos estos paquetes en vuestra distro debian-ubuntu:
sudo apt update
sudo apt install --install-recommends libpulse0:i386 pipewire-alsa:i386 libspa-0.2-modules:i386 libc6:i386 libstdc++6:i386 libgcc-s1:i386 libgl1:i386 libgl1-mesa-dri:i386 libglx-mesa0:i386 libsdl2-2.0-0:i386 libasound2-plugins:i386 libpulse0:i386 libfontconfig1:i386 libfreetype6:i386 zlib1g:i386
13.  bien, ahora una vez acabado, teclear ./xash3d
14.  ahora id a "custom game" y seleccionad counter-life
15.  dadle a new game-seleccionais la dificultad y se arrancara el juego sin problemas

bueno, pues esto es todo, disfruten de este super-mod
