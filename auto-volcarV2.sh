#!/bin/bash

comprobacion_sudo(){
uuid=`id -u`
if [ $uuid -ne 0 ]
then
	echo "Debe ejecutarse como administrador, pruebe con sudo $nombre"
	exit 1
fi
}

comprobacion_parametro(){
if [ $parametros -ne 1 ]
then
        echo "Se debe indicar la maqueta que vaya a volcarse"
        exit 2
fi
}

comprobacion_ficheros(){
if [ ! -f "./fsarchiver" ]; then
	echo "Debes tener el script de fsarchiver en el mismo directorio"
	exit 3
fi
if [ ! -f "./autodestruccion" ]; then
	echo "El script autodestruccion debe estar en el mismo directorio"
	exit 4
fi
}

preguntas() {
echo -e "El ordenador utiliza UEFI (s/n):"
read uefi
echo -e "Solo tiene GNU/Linux instalado (s/n):"
read dual
echo -e "Tamaño particion SWAP (Por defecto: 4096MB)"
read size_swap
echo -e "Tamaño particion sistema (Por defecto: 30720MB)"
read size_sis
echo -e "Introduzca nuevo nombre de host:"
read hostname
}

conversion_datos(){
case $uefi in
	n|N|no|NO|No|nO) uefi=NO;;
	s|S|si|SI|Si|sI) uefi=SI;;
esac
case $dual in
	n|N|no|NO|No|nO) dual=NO;;
	s|S|si|SI|Si|sI) dual=SI;;
esac
if [ ! $size_swap ]; then
	size_swap=4096M
fi
if [ ! $size_sis ]; then
	size_sis=30720M
fi
}

datos(){
echo
echo
echo "LOS DATOS A UTILIZAR SERAN LOS SIGUIENTES"
echo "========================================="
echo -e "Maqueta que se utilizara: \t $maqueta"
echo -e "Tamaño de swap:\t\t\t $size_swap"
echo -e "Tamaño del sistema:\t\t $size_sis"
echo -e "Ordenador con UEFI:\t\t $uefi"
echo -e "Solo GNU/Linux:\t\t\t $dual"
echo
echo
echo "Son correctos los datos? (s/n)"
read respuesta
}


particiones_noUEFI_alldisk() {
(
echo o #Creacion de nueva tabla de particiones

echo n #Nueva particion SWAP
echo p #Particion primaria
echo 1 #Numero de la particion
echo #Posicionado al principio del disco
echo +$size_swap #Tamano total de la particion SWAP

echo n #Nueva particion /
echo p #Particion primaria
echo 2 #Numero de la particion
echo #Posicionado justo despues de la anterior
echo +$size_sis #Tamano total de la particion /

echo n #Nueva particion /home
echo p #Particion primaria
echo 3 #Numero de la particion
echo #Posicionado justo despues de la anterior
echo #El resto del tamano

echo w #Guardar cambios
) | fdisk /dev/sda
mkswap /dev/sda1 #Formatear en swap
(echo s) | mkfs.ext4 /dev/sda2 #Formateo en ext4
(echo s) | mkfs.ext4 /dev/sda3 #Formateo en ext4
part_swap="/dev/sda1"
part_sis="/dev/sda2"
part_home="/dev/sda3"
}

particiones_siUEFI_alldisk(){
(
echo o #Creacion de nueva tabla de particiones

echo n #Nueva particion UEFI
echo p #Particion primaria
echo 1 #Numero de la particion
echo #Posicionado al principio del disco
echo +512M #Tamaño total de la particion UEFI

echo n #Nueva particion SWAP
echo p #Particion primaria
echo 2 #Numero de la particion
echo #Posicionado justo despues de la anterior
echo +$size_swap #Tamaño total de la particion SWAP

echo n #Nueva particion /
echo p #Particion primaria
echo 3 #Numero de la particion
echo #Posicionado justo despues de la anterior
echo +$size_sis #Tamaño total de la particion /

echo n #Nueva particion /home
echo p #Particion primaria
echo 4 #Numero de la particion
echo #Posicionado justo despues de la anterior
echo #El resto del tamano

echo w #Guardar cambios
) | fdisk /dev/sda
(echo s) | mkfs.vfat -F 32 /dev/sda1 #Formateo de la particion UEFI
mkswap /dev/sda2 #Formateo de la particion SWAP
(echo s) | mkfs.ext4 /dev/sda3 #Formateo de la particion /
(echo s) | mkfs.ext4 /dev/sda4 #Formateo de la particion /home
part_uefi="/dev/sda1"
part_swap="/dev/sda2"
part_sis="/dev/sda3"
part_home="/dev/sda4"
}

particiones_noUEFI_halfdisk() {
particion_extend=`fdisk -l | grep Extend | cut -d " " -f 1 | cut -c9`
formato_tabla_part=`fdisk -l /dev/sda | grep type | cut -d " " -f3`
(
echo d #borrar particion extendida
echo $particion_extend #numero particion

echo n #Nueva particion SWAP
echo e #Particion extendida
if [ $formato_tabla_part != dos]; then
echo $particion_extend
fi
echo #Posicionado justo despues de la anterior
echo #El resto del tamano

echo n #Nueva particion SWAP
echo l #Particion logica
echo #Posicionado al principio del disco
echo +$size_swap #Tamano total de la particion SWAP

echo n #Nueva particion /
echo l #Particion logica
echo #Posicionado justo despues de la anterior
echo +$size_sis #Tamano total de la particion /

echo n #Nueva particion /home
echo l #Particion logica
echo #Posicionado justo despues de la anterior
echo #El resto del tamano

echo w #Guardar cambios
) | fdisk /dev/sda
mkswap /dev/sda1 #Formatear en swap
(echo s) | mkfs.ext4 /dev/sda2 #Formateo en ext4
(echo s) | mkfs.ext4 /dev/sda3 #Formateo en ext4
part_swap="/dev/sda5"
part_sis="/dev/sda6"
part_home="/dev/sda7"
}

particiones_noUEFI_halfdisk() {
particion_extend=`fdisk -l | grep Extend | cut -d " " -f 1 | cut -c9`
formato_tabla_part=`fdisk -l /dev/sda | grep type | cut -d " " -f3`
(
echo d #borrar particion extendida
echo $particion_extend #numero particion

echo n #Nueva particion SWAP
echo e #Particion extendida
if [ $formato_tabla_part != dos]; then
echo $particion_extend
fi
echo #Posicionado justo despues de la anterior
echo #El resto del tamano

echo n #Nueva particion UEFI
echo l #Particion primaria
echo #Posicionado al principio del disco
echo +512M #Tamaño total de la particion UEFI

echo n #Nueva particion SWAP
echo l #Particion primaria
echo #Posicionado justo despues de la anterior
echo +$size_swap #Tamaño total de la particion SWAP

echo n #Nueva particion /
echo l #Particion primaria
echo #Posicionado justo despues de la anterior
echo +$size_sis #Tamaño total de la particion /

echo n #Nueva particion /home
echo l #Particion primaria
echo #Posicionado justo despues de la anterior
echo #El resto del tamano

echo w #Guardar cambios
) | fdisk /dev/sda
(echo s) | mkfs.vfat -F 32 /dev/sda1 #Formateo de la particion UEFI
mkswap /dev/sda2 #Formateo de la particion SWAP
(echo s) | mkfs.ext4 /dev/sda3 #Formateo de la particion /
(echo s) | mkfs.ext4 /dev/sda4 #Formateo de la particion /home
part_uefi="/dev/sda1"
part_swap="/dev/sda2"
part_sis="/dev/sda3"
part_home="/dev/sda4"
}

cambio_hostname(){
#Cambio fichero hostname
echo $hostname > /mnt/etc/hostname
#Cambio fichero hosts
sed "2 c127.0.1.1\t$hostname" /mnt/etc/hosts > /tmp/hosts
cat /tmp/hosts > /mnt/etc/hosts
}

cambio_uuid_swap(){
uuid_swap=`blkid | grep $part_swap | cut -d '"' -f 2`

linia_swap1=`cat -n /mnt/etc/fstab | grep swap | cut -f 1 | tr "\n" "," | cut -d "," -f 1`
linia_swap2=`cat -n /mnt/etc/fstab | grep swap | cut -f 1 | tr "\n" "," | cut -d "," -f 2`

sed "$linia_swap1,$linia_swap2 s/UUID=[A-Za-z0-9-]*/UUID=$uuid_swap/" /mnt/etc/fstab > /tmp/fstab
cat /tmp/fstab > /mnt/etc/fstab

}

cambio_uuid_uefi(){
uuid_uefi=`blkid | grep $part_uefi | cut -d '"' -f 2`

linia_uefi=`cat -n /mnt/etc/fstab | grep vfat | cut -f 1`

sed "$linia_uefi s/UUID=[A-Za-z0-9-]*/UUID=$uuid_uefi/" /mnt/etc/fstab > /tmp/fstab
cat /tmp/fstab > /mnt/etc/fstab

}

auto_grub(){
sed "13 c/srv/autodestruccion" /etc/rc.local > /tmp/rc.local
cat /tmp/rc.local > /etc/rc.local
cp -p ./autodestruccion /srv/autodestruccion
}

auto_chroot(){
echo "Mount uefi"
mount $part_uefi /mnt/boot/efi
mount -t proc /proc /mnt/proc
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys

(
echo grub-install
) | chroot /mnt
}

#Parametros pasados a variables
parametros=$#
maqueta=$1
nombre=$0
continuar=0
#Comprobaciones
comprobacion_sudo
comprobacion_parametro
comprobacion_ficheros
clear

until [ $continuar = si ]
do
	preguntas
	conversion_datos
	datos
	case $respuesta in
		n|N|no|NO|No|nO) continuar=no;;
		*) continuar=si;;
	esac
done
#Empezamos con el volcado
echo
echo "Empecemos"
echo
#Formateo del disco segun las opciones indicadas
if [ $dual = "SI" ] && [ $uefi = "NO" ];then
	echo "Particiones no UEFI todo el disco"
	echo
	particiones_noUEFI_alldisk
elif [ $dual = "SI" ] && [ $uefi = "SI" ];then
	echo "Particiones UEFI todo el disco"
	echo
	particiones_siUEFI_alldisk
elif [ $dual = "NO" ] && [ $uefi = "NO" ];then
	echo "Particiones no UEFI medio disco"
	echo
elif [ $dual = "NO" ] && [ $uefi = "SI" ];then
	echo "Particiones UEFI medio disco"
	echo
else
	echo "Algo ha fallado"
	exit 5
fi
#Fsarchiver
echo "Empezando proceso de volcado"
echo
./fsarchiver -v restfs $maqueta dest=$part_sis,id=0 dest=$part_home,id=1
echo
#Montar particion de sistema en /mnt
echo "Montando la particion $part_sis en /mnt"
mount $part_sis /mnt
echo
#Cambio de hostname
echo "Cambiando el nombre de host por $hostname"
cambio_hostname
echo
echo "Cambiando el uuid de la particion swap en el /etc/fstab"
cambio_uuid_swap
if [ $part_uefi ]; then
	echo
	echo "Equipo con UEFI"
	echo "==============="
	echo
	echo "Cambiando el uuid de la particion uefi en el /etc/fstab"
	cambio_uuid_uefi
	echo "Instalando el grub"
	auto_chroot
else
	echo
	echo "Equipo sin UEFI"
	echo "==============="
	echo
	echo "Instalando el grub"
	grub-install --root-directory=/mnt /dev/sda
fi
echo
echo "Preparando para el reinicio"
auto_grub
echo
echo "Reiniciando"

reboot
echo "FIN"
